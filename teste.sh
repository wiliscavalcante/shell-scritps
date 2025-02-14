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
          
          # Gerar checksums confiáveis apenas do conteúdo dos arquivos, ignorando metadados
          CURRENT_ENV_CHECKSUM=$(chroot /host /bin/sh -c 'find /env-config -type f ! -name ".*" ! -name "*.tmp" ! -name "*~" | sort | xargs cat | sha256sum' | awk '{print $1}')
          CURRENT_CERTS_CHECKSUM=$(chroot /host /bin/sh -c 'find /certs -type f ! -name ".*" ! -name "*.tmp" ! -name "*~" | sort | xargs cat | sha256sum' | awk '{print $1}')
          
          echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✅ Estado atual dos ConfigMaps e Certificados lido com sucesso"
          echo "Último checksum salvo das variáveis: $LAST_ENV_CHECKSUM"
          echo "Último checksum salvo dos certificados: $LAST_CERTS_CHECKSUM"
          echo "Checksum ATUAL das variáveis: $CURRENT_ENV_CHECKSUM"
          echo "Checksum ATUAL dos certificados: $CURRENT_CERTS_CHECKSUM"
          
          RESTART_CONTAINERD=false
          
          # Atualizar variáveis se necessário
          if [ "$CURRENT_ENV_CHECKSUM" != "$LAST_ENV_CHECKSUM" ]; then
              echo "[$(date '+%Y-%m-%d %H:%M:%S')] 🚀 Alteração detectada nas variáveis, aplicando atualização..."
              chroot /host /bin/sh /tmp/update_env.sh
              echo "$CURRENT_ENV_CHECKSUM" > "$ENV_CHECKSUM_FILE"
              RESTART_CONTAINERD=true
          else
              echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✅ Nenhuma alteração detectada nas variáveis, pulando atualização."
          fi
          
          # Atualizar certificados se necessário
          if [ "$CURRENT_CERTS_CHECKSUM" != "$LAST_CERTS_CHECKSUM" ]; then
              echo "[$(date '+%Y-%m-%d %H:%M:%S')] 🚀 Alteração detectada nos certificados, aplicando atualização..."
              mkdir -p /host/etc/pki/ca-trust/source/anchors/
              cp -u /host/certs/* /host/etc/pki/ca-trust/source/anchors/
              chroot /host update-ca-trust extract
              echo "$CURRENT_CERTS_CHECKSUM" > "$CERTS_CHECKSUM_FILE"
              RESTART_CONTAINERD=true
          else
              echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✅ Nenhuma alteração detectada nos certificados, pulando atualização."
          fi
          
          # Reiniciar containerd apenas se necessário
          if [ "$RESTART_CONTAINERD" = "true" ]; then
              echo "[$(date '+%Y-%m-%d %H:%M:%S')] 🔹 Reiniciando containerd..."
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
