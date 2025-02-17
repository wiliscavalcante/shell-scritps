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
        command: ["/bin/sh", "-c"]
        args:
        - |
          echo "========== 🔹 Iniciando configuração do DaemonSet =========="

          # Definir locais para armazenar os checksums
          ENV_CHECKSUM_FILE="/host/etc/env-config-checksum"
          CERTS_CHECKSUM_FILE="/host/etc/certs-config-checksum"
          CONFIG_DIR="/env-config"
          CERTS_DIR="/host/certs"

          # Criar os arquivos de checksum se não existirem
          [ ! -f "$ENV_CHECKSUM_FILE" ] && echo "" > "$ENV_CHECKSUM_FILE"
          [ ! -f "$CERTS_CHECKSUM_FILE" ] && echo "" > "$CERTS_CHECKSUM_FILE"

          # Ler os últimos checksums salvos
          LAST_ENV_CHECKSUM=$(cat "$ENV_CHECKSUM_FILE" 2>/dev/null || echo "")
          LAST_CERTS_CHECKSUM=$(cat "$CERTS_CHECKSUM_FILE" 2>/dev/null || echo "")

          # Gerar novos checksums
          CURRENT_ENV_CHECKSUM=$(chroot /host /bin/sh -c 'find /env-config -type f ! -name ".*" | sort | xargs cat | sha256sum' | awk '{print $1}')
          CURRENT_CERTS_CHECKSUM=$(chroot /host /bin/sh -c 'find /certs -type f ! -name ".*" | sort | xargs cat | sha256sum' | awk '{print $1}')

          echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✅ Estado atual dos ConfigMaps lido com sucesso"
          echo "Último checksum de variáveis: $LAST_ENV_CHECKSUM"
          echo "Checksum ATUAL de variáveis: $CURRENT_ENV_CHECKSUM"
          echo "Último checksum de certificados: $LAST_CERTS_CHECKSUM"
          echo "Checksum ATUAL de certificados: $CURRENT_CERTS_CHECKSUM"

          # Criar script de manipulação de variáveis de ambiente
          cat << 'EOF' > /host/tmp/update_env.sh
          #!/bin/sh
          CONFIG_DIR="/env-config"
          TEMP_ENV="/etc/environment.tmp"
          TEMP_LIST="/tmp/env_list.tmp"

          echo "[$(date '+%Y-%m-%d %H:%M:%S')] 🔹 Iniciando atualização das variáveis de ambiente"

          cp /etc/environment $TEMP_ENV

          for CONFIG_FILE in "$CONFIG_DIR"/*; do
              VAR_NAME=$(basename "$CONFIG_FILE")
              NEW_VALUES=$(cat "$CONFIG_FILE" 2>/dev/null | tr -d '\n' || echo "")

              if [ -n "$NEW_VALUES" ]; then
                  if grep -qi "^$VAR_NAME=" /etc/environment; then
                      EXISTING_VALUES=$(grep -i "^$VAR_NAME=" /etc/environment | cut -d'=' -f2- | tr ',' '\n')

                      # Junta os valores existentes e novos, removendo duplicatas
                      echo "$EXISTING_VALUES" > "$TEMP_LIST"
                      echo "$NEW_VALUES" | tr ',' '\n' >> "$TEMP_LIST"
                      FINAL_LIST=$(awk '!seen[$0]++' "$TEMP_LIST" | paste -sd, -)

                      # Atualiza a variável no arquivo temporário
                      sed -i "/^$VAR_NAME=/c\\$VAR_NAME=$FINAL_LIST" $TEMP_ENV
                      echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✅ $VAR_NAME atualizada: $FINAL_LIST"
                  else
                      echo "$VAR_NAME=$NEW_VALUES" >> $TEMP_ENV
                      echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✅ $VAR_NAME criada: $NEW_VALUES"
                  fi
              else
                  echo "[$(date '+%Y-%m-%d %H:%M:%S')] 🔹 Nenhuma atualização necessária para $VAR_NAME (ConfigMap vazio ou ausente)"
              fi
          done

          rm -f $TEMP_LIST
          mv $TEMP_ENV /etc/environment

          # **Executa o export para recarregar as variáveis no sistema**
          # chroot /host /bin/sh -c 'export $(grep -v "^#" /etc/environment | xargs)'
          echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✅ Variáveis de ambiente recarregadas no sistema."
          EOF

          chmod +x /host/tmp/update_env.sh

            echo "========== 🔹 Verificando alterações nas variáveis de ambiente =========="
            if [ "$CURRENT_ENV_CHECKSUM" != "$LAST_ENV_CHECKSUM" ]; then
              echo "🚀 Alteração detectada nas variáveis de ambiente. Aplicando reconfiguração..."
              chroot /host /bin/sh /tmp/update_env.sh
              echo "$CURRENT_ENV_CHECKSUM" > "$ENV_CHECKSUM_FILE"
              
              # **Recarregar variáveis no nó do EKS**
              echo "[$(date '+%Y-%m-%d %H:%M:%S')] 🔹 Recarregando variáveis de ambiente no nó..."
              chroot /host /bin/sh -c 'export $(grep -v "^#" /etc/environment | xargs)'
              echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✅ Variáveis de ambiente aplicadas ao nó do EKS."
              
              RESTART_CONTAINERD=true
            else
              echo "✅ Nenhuma alteração detectada nas variáveis de ambiente. Pulando esta etapa."
            fi
           
          echo "========== 🔹 Verificando alterações nos certificados =========="
          if [ "$CURRENT_CERTS_CHECKSUM" != "$LAST_CERTS_CHECKSUM" ]; then
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
          if [ "${RESTART_CONTAINERD:-false}" = "true" ]; then
              echo "🔹 Reiniciando containerd..."
              chroot /host /bin/sh -c '
              if command -v systemctl &> /dev/null; then
                  systemctl restart containerd && echo "✅ containerd reiniciado com systemctl!" && exit 0
              fi
              kill -HUP $(pidof containerd) && echo "✅ containerd recarregado via HUP!" || echo "❌ Falha ao reiniciar containerd!"
              '
          else
              echo "✅ Nenhuma mudança relevante detectada. containerd não será reiniciado."
          fi

          echo "========== ✅ Configuração finalizada! =========="

          exec sleep infinity
        volumeMounts:
        - name: host-root
          mountPath: /host
        - name: certs
          mountPath: /host/certs
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
