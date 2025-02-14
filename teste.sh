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
        imagePullPolicy: IfNotPresent
        securityContext:
          privileged: true
        env:
        - name: FORCE_RECONFIGURE
          value: "true"
        command: ["/bin/sh", "-c"]
        args:
        - |
          echo "========== 🔹 Iniciando configuração do DaemonSet =========="

          # Definir locais para armazenar os checksums
          ENV_CHECKSUM_FILE="/host/etc/env-config-checksum"
          CONFIG_DIR="/env-config"

          # Criar os arquivos de checksum se não existirem
          [ ! -f "$ENV_CHECKSUM_FILE" ] && echo "" > "$ENV_CHECKSUM_FILE"

          # Ler o último checksum salvo
          LAST_ENV_CHECKSUM=$(cat "$ENV_CHECKSUM_FILE" 2>/dev/null || echo "")

          # Gerar checksum confiável apenas do conteúdo dos arquivos, ignorando metadados
          CURRENT_ENV_CHECKSUM=$(chroot /host /bin/sh -c 'find /env-config -type f ! -name ".*" ! -name "*.tmp" ! -name "*~" | sort | xargs cat | sha256sum' | awk '{print $1}')

          echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✅ Estado atual dos ConfigMaps lido com sucesso"
          echo "Último checksum salvo: $LAST_ENV_CHECKSUM"
          echo "Checksum ATUAL: $CURRENT_ENV_CHECKSUM"

          echo "========== 🔹 Criando script de manipulação de variáveis =========="
          cat << 'EOF' > /host/tmp/update_env.sh
          #!/bin/sh
          ENV_FILE="/etc/environment"
          CONFIG_DIR="/env-config"

          echo "[$(date '+%Y-%m-%d %H:%M:%S')] 🔹 Iniciando atualização de variáveis no ambiente"

          update_variable() {
              VAR_NAME=$1
              VALUE=$2

              if grep -q "^$VAR_NAME=" "$ENV_FILE"; then
                  EXISTING_VALUE=$(grep "^$VAR_NAME=" "$ENV_FILE" | cut -d'=' -f2- | tr -d '"')
                  IFS=',' read -r -a EXISTING_ARRAY <<< "$EXISTING_VALUE"
                  IFS=',' read -r -a NEW_VALUES <<< "$VALUE"

                  declare -A VALUE_SET
                  for ITEM in "${EXISTING_ARRAY[@]}"; do
                      VALUE_SET["$ITEM"]=1
                  done

                  for ITEM in "${NEW_VALUES[@]}"; do
                      if [[ -z "${VALUE_SET[$ITEM]}" ]]; then
                          EXISTING_ARRAY+=("$ITEM")
                          VALUE_SET["$ITEM"]=1
                      fi
                  done

                  UPDATED_VALUE=$(IFS=','; echo "${EXISTING_ARRAY[*]}")
                  sed -i "s|^$VAR_NAME=.*|$VAR_NAME=$UPDATED_VALUE|" "$ENV_FILE"
                  echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✅ Variável $VAR_NAME atualizada: $UPDATED_VALUE"
              else
                  echo "[$(date '+%Y-%m-%d %H:%M:%S')] ⚠️ Variável $VAR_NAME não encontrada, ignorando..."
              fi
          }

          if [ "$CURRENT_ENV_CHECKSUM" != "$LAST_ENV_CHECKSUM" ]; then
              for VAR_FILE in $(ls "$CONFIG_DIR"); do
                  VAR_NAME=$(basename "$VAR_FILE")
                  VALUE=$(grep "value:" "$CONFIG_DIR/$VAR_FILE" | cut -d':' -f2 | tr -d ' ' | tr -d '"')

                  if [ -z "$VALUE" ]; then
                      echo "[$(date '+%Y-%m-%d %H:%M:%S')] ❌ ERRO: Valor ausente para $VAR_NAME. Pulando..."
                      continue
                  fi

                  update_variable "$VAR_NAME" "$VALUE"
              done

              echo "$CURRENT_ENV_CHECKSUM" > "$ENV_CHECKSUM_FILE"
              echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✅ Todas as variáveis foram atualizadas com sucesso!"
          else
              echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✅ Nenhuma alteração detectada, pulando atualização de variáveis."
          fi
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
