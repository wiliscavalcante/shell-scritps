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
          echo "[$(date '+%Y-%m-%d %H:%M:%S')] 🔹 Iniciando configuração do DaemonSet"
          ENV_CHECKSUM_FILE="/host/etc/env-config-checksum"
          CONFIG_DIR="/host/env-config"
          
          [ ! -f "$ENV_CHECKSUM_FILE" ] && echo "" > "$ENV_CHECKSUM_FILE"
          LAST_ENV_CHECKSUM=$(cat "$ENV_CHECKSUM_FILE" 2>/dev/null || echo "")
          CURRENT_ENV_CHECKSUM=$(chroot /host /bin/sh -c 'find /env-config -type f -exec cat {} \; | sha256sum' | awk '{print $1}')
          
          if [ "$CURRENT_ENV_CHECKSUM" = "$LAST_ENV_CHECKSUM" ]; then
              echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✅ Nenhuma alteração detectada nos ConfigMaps. Pulando execução."
              exec sleep infinity  # Mantém o container rodando
          fi
          
          echo "$CURRENT_ENV_CHECKSUM" > "$ENV_CHECKSUM_FILE"
          
          update_proxy_vars() {
              VAR_NAME=$1
              NEW_VALUE=$2
              ENV_FILE="/etc/environment"
              
              echo "[$(date '+%Y-%m-%d %H:%M:%S')] 🔹 Tentando atualizar $VAR_NAME em $ENV_FILE"
              
              if ! chroot /host test -w "$ENV_FILE"; then
                  echo "[$(date '+%Y-%m-%d %H:%M:%S')] ❌ ERRO: Sem permissão para modificar $ENV_FILE"
                  exit 1
              fi
              
              if chroot /host grep -q "^$VAR_NAME=" "$ENV_FILE"; then
                  EXISTING_VALUE=$(chroot /host grep "^$VAR_NAME=" "$ENV_FILE" | cut -d'=' -f2- | tr -d '"')
                  UPDATED_VALUE=$(echo "$EXISTING_VALUE,$NEW_VALUE" | awk -F, '{for(i=1;i<=NF;i++) if(!a[$i]++) printf (i==1 ? "%s" : ",%s"),$i; print ""}')
                  chroot /host sed -i "s|^$VAR_NAME=.*|$VAR_NAME=\"$UPDATED_VALUE\"|" "$ENV_FILE"
              else
                  echo "$VAR_NAME=\"$NEW_VALUE\"" | chroot /host tee -a "$ENV_FILE"
              fi
              
              echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✅ $VAR_NAME atualizado para: $(chroot /host grep "^$VAR_NAME=" "$ENV_FILE" | cut -d'=' -f2-)"
          }
          
          NO_PROXY_VALUES=$(chroot /host cat "$CONFIG_DIR/NO_PROXY" 2>/dev/null || echo "")
          no_proxy_VALUES=$(chroot /host cat "$CONFIG_DIR/no_proxy" 2>/dev/null || echo "")
          
          if [ -n "$NO_PROXY_VALUES" ]; then
              update_proxy_vars "NO_PROXY" "$NO_PROXY_VALUES"
              update_proxy_vars "no_proxy" "$NO_PROXY_VALUES"
          fi
          
          if [ -n "$no_proxy_VALUES" ]; then
              update_proxy_vars "NO_PROXY" "$no_proxy_VALUES"
              update_proxy_vars "no_proxy" "$no_proxy_VALUES"
          fi
          
          echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✅ Variáveis de proxy configuradas com sucesso!"
          
          echo "[$(date '+%Y-%m-%d %H:%M:%S')] 🔹 Reiniciando containerd..."
          chroot /host /bin/sh -c 'systemctl restart containerd || kill -HUP $(pidof containerd)'
          echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✅ containerd reiniciado!"
          
          echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✅ Configuração finalizada!"
          exec sleep infinity  # Mantém o container rodando
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
          optional: true
      - name: env-config
        configMap:
          name: env-config
          optional: true
      hostNetwork: true
      hostPID: true
