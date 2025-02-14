apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: eks-node-config-agent
  namespace: kube-system
spec:
  selector:
    matchLabels:
      name: eks-node-config-agent
  template:
    metadata:
      labels:
        name: eks-node-config-agent
    spec:
      tolerations:
      - key: "dedicated"
        operator: "Equal"
        value: "infra"
        effect: "NoSchedule"
      - key: "node-role.kubernetes.io/control-plane"
        effect: "NoSchedule"
      - key: "node-role.kubernetes.io/master"
        effect: "NoSchedule"
      containers:
      - name: node-config-agent
        image: amazonlinux:latest
        imagePullPolicy: Always
        securityContext:
          privileged: true
        env:
        - name: FORCE_RECONFIGURE
          value: "false"
        command: ["/bin/sh", "-c"]
        args:
        - |
          echo "========== 🔹 Iniciando configuração do DaemonSet =========="

          # Definir locais para armazenar os checksums
          ENV_CHECKSUM_FILE="/host/etc/env-config-checksum"
          CERTS_CHECKSUM_FILE="/host/etc/certs-config-checksum"

          # Criar os arquivos de checksum se não existirem
          [ ! -f "$ENV_CHECKSUM_FILE" ] && echo "" > "$ENV_CHECKSUM_FILE"
          [ ! -f "$CERTS_CHECKSUM_FILE" ] && echo "" > "$CERTS_CHECKSUM_FILE"

          # Ler os últimos checksums salvos
          LAST_ENV_CHECKSUM=$(cat "$ENV_CHECKSUM_FILE" 2>/dev/null || echo "")
          LAST_CERTS_CHECKSUM=$(cat "$CERTS_CHECKSUM_FILE" 2>/dev/null || echo "")

          # Gerar checksums confiáveis apenas do conteúdo dos arquivos, ignorando metadados e garantindo ordem
          CURRENT_ENV_CHECKSUM=$(chroot /host /bin/sh -c 'find /env-config -type f ! -name ".*" ! -name "*.tmp" ! -name "*~" | sort | xargs cat | sha256sum' | awk '{print $1}')
          CURRENT_CERTS_CHECKSUM=$(chroot /host /bin/sh -c 'find /certs -type f ! -name ".*" ! -name "*.tmp" ! -name "*~" | sort | xargs cat | sha256sum' | awk '{print $1}')

          echo "✅ Estado atual dos ConfigMaps lido com sucesso"
          echo "Último checksum das variáveis salvo: $LAST_ENV_CHECKSUM"
          echo "Último checksum dos certificados salvo: $LAST_CERTS_CHECKSUM"
          echo "Checksum ATUAL das variáveis: $CURRENT_ENV_CHECKSUM"
          echo "Checksum ATUAL dos certificados: $CURRENT_CERTS_CHECKSUM"

          echo "========== 🔹 Criando script de manipulação de variáveis =========="
          cat << 'EOF' > /host/tmp/update_env.sh
          #!/bin/sh
          ENV_FILE="/etc/environment"
          CONFIG_DIR="/env-config"
          VALID_VARIABLES="/tmp/valid_variables.list"
          echo "" > "$VALID_VARIABLES"

          update_variable() {
              VAR_NAME=$1
              MODE=$2
              VALUE=$3

              echo "$VAR_NAME" >> "$VALID_VARIABLES"

              if grep -q "^$VAR_NAME=" "$ENV_FILE"; then
                  if [ "$MODE" = "append" ]; then
                      EXISTING_VALUE=$(grep "^$VAR_NAME=" "$ENV_FILE" | cut -d'=' -f2- | tr -d '"')
                      if [[ "$EXISTING_VALUE" != *"$VALUE"* ]]; then
                          echo "✅ Incrementado valor em $VAR_NAME: $VALUE"
                          sed -i "s|^$VAR_NAME=.*|$VAR_NAME=$VALUE|" "$ENV_FILE"
                      fi
                  elif [ "$MODE" = "overwrite" ]; then
                      echo "✅ Substituindo valor de $VAR_NAME"
                      sed -i "s|^$VAR_NAME=.*|$VAR_NAME=$VALUE|" "$ENV_FILE"
                  fi
              else
                  echo "$VAR_NAME=$VALUE" >> "$ENV_FILE"
                  echo "✅ Criada nova variável: $VAR_NAME"
              fi
          }

          for VAR_FILE in $(ls "$CONFIG_DIR"); do
              VAR_NAME=$(basename "$VAR_FILE")
              MODE=$(grep "mode:" "$CONFIG_DIR/$VAR_FILE" | cut -d':' -f2 | tr -d ' ')
              VALUE=$(grep "value:" "$CONFIG_DIR/$VAR_FILE" | cut -d':' -f2 | tr -d ' ' | tr -d '"')

              if [ -z "$MODE" ] || [ -z "$VALUE" ]; then
                  echo "❌ ERRO: Modo ou valor ausente para $VAR_NAME. Pulando..."
                  continue
              fi

              update_variable "$VAR_NAME" "$MODE" "$VALUE"
              VAR_NAME_UPPER=$(echo "$VAR_NAME" | tr '[:lower:]' '[:upper:]')
              update_variable "$VAR_NAME_UPPER" "$MODE" "$VALUE"
          done

          echo "🔹 Removendo variáveis não presentes no ConfigMap..."
          grep -o '^[^=]*' "$ENV_FILE" | while read -r VAR; do
              if ! grep -qx "$VAR" "$VALID_VARIABLES"; then
                  echo "❌ Removendo variável obsoleta: $VAR"
                  sed -i "/^$VAR=/d" "$ENV_FILE"
              fi
          done

          echo "✅ Todas as variáveis aplicadas com sucesso!"
          EOF

          chmod +x /host/tmp/update_env.sh

          echo "========== 🔹 Verificando alterações nas variáveis de ambiente =========="
          if [ "$FORCE_RECONFIGURE" = "true" ] || [ "$CURRENT_ENV_CHECKSUM" != "$LAST_ENV_CHECKSUM" ]; then
              echo "🚀 Alteração detectada nas variáveis de ambiente. Aplicando reconfiguração..."
              chroot /host /bin/sh /tmp/update_env.sh
              echo "$CURRENT_ENV_CHECKSUM" > "$ENV_CHECKSUM_FILE"
              RESTART_CONTAINERD=true
          else
              echo "✅ Nenhuma alteração detectada nas variáveis de ambiente. Pulando esta etapa."
          fi

          echo "========== 🔹 Verificando alterações nos certificados =========="
          if [ "$FORCE_RECONFIGURE" = "true" ] || [ "$CURRENT_CERTS_CHECKSUM" != "$LAST_CERTS_CHECKSUM" ]; then
              echo "🚀 Alteração detectada nos certificados. Aplicando reconfiguração..."
              mkdir -p /host/etc/pki/ca-trust/source/anchors/
              cp /host/certs/* /host/etc/pki/ca-trust/source/anchors/
              chroot /host update-ca-trust extract
              echo "✅ Certificados instalados e atualizados!"
              echo "$CURRENT_CERTS_CHECKSUM" > "$CERTS_CHECKSUM_FILE"
              RESTART_CONTAINERD=true
          else
              echo "✅ Nenhuma alteração detectada nos certificados. Pulando esta etapa."
          fi

          echo "========== 🔹 Verificando necessidade de reinicialização do containerd =========="

          if [ "$RESTART_CONTAINERD" = "true" ]; then
              echo "🔹 Reiniciando containerd..."
              chroot /host /bin/sh -c '
              if command -v systemctl &> /dev/null; then
                  systemctl restart containerd && echo "✅ containerd reiniciado com systemctl!" && exit 0
              fi
              
              kill -HUP $(pidof containerd) && echo "✅ containerd recarregado via HUP!" || echo "❌ Falha ao reiniciar containerd!"
              '
          else
              echo "✅ Nenhuma mudança relevante detectada. `containerd` não será reiniciado."
          fi

          echo "========== ✅ Configuração finalizada! =========="

          exec sleep infinity
        volumeMounts:
        - name: host-root
          mountPath: /host
        - name: certs
          mountPath: host/certs
        - name: env-config
          mountPath: /host/env-config
          readOnly: true
      volumes:
      - name: host-root
        hostPath:
          path: /
      - name: certs
        configMap:
          name: certs-config
      - name: env-config
        configMap:
          name: env-config
      hostNetwork: true
      hostPID: true
