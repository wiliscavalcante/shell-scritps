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
          ENV_CHECKSUM_FILE="/host/etc/env-config-checksum"
          CERTS_CHECKSUM_FILE="/host/etc/certs-config-checksum"
          CONFIG_DIR="/env-config"
          CERTS_DIR="/host/certs"
          
          [ ! -f "$ENV_CHECKSUM_FILE" ] && echo "" > "$ENV_CHECKSUM_FILE"
          [ ! -f "$CERTS_CHECKSUM_FILE" ] && echo "" > "$CERTS_CHECKSUM_FILE"
          
          LAST_ENV_CHECKSUM=$(cat "$ENV_CHECKSUM_FILE" 2>/dev/null || echo "")
          LAST_CERTS_CHECKSUM=$(cat "$CERTS_CHECKSUM_FILE" 2>/dev/null || echo "")
          
          CURRENT_ENV_CHECKSUM=$(chroot /host /bin/sh -c 'find /env-config -type f -exec cat {} \; | sha256sum' | awk '{print $1}')
          CURRENT_CERTS_CHECKSUM=$(chroot /host /bin/sh -c 'find /host/certs -type f -exec cat {} \; | sha256sum' | awk '{print $1}')
          
          if [ "$CURRENT_ENV_CHECKSUM" = "$LAST_ENV_CHECKSUM" ] && [ "$CURRENT_CERTS_CHECKSUM" = "$LAST_CERTS_CHECKSUM" ]; then
              echo "✅ Nenhuma alteração detectada nos ConfigMaps. Pulando execução."
              exit 0
          fi
          
          echo "$CURRENT_ENV_CHECKSUM" > "$ENV_CHECKSUM_FILE"
          echo "$CURRENT_CERTS_CHECKSUM" > "$CERTS_CHECKSUM_FILE"
          
          update_variable() {
              VAR_NAME=$1
              NEW_VALUE=$2
              ENV_FILE="/host/etc/environment"
              STATE_FILE="/host/tmp/${VAR_NAME}_managed_values"
              
              touch "$STATE_FILE"
              VAR_NAME_UPPER=$(echo "$VAR_NAME" | tr '[:lower:]' '[:upper:]')
              VAR_NAME_LOWER=$(echo "$VAR_NAME" | tr '[:upper:]' '[:lower:]')
              
              update_single_variable "$VAR_NAME_UPPER" "$NEW_VALUE" "$STATE_FILE"
              update_single_variable "$VAR_NAME_LOWER" "$NEW_VALUE" "$STATE_FILE"
          }
          
          update_single_variable() {
              VAR_NAME=$1
              NEW_VALUE=$2
              STATE_FILE=$3
              ENV_FILE="/host/etc/environment"
              
              EXISTING_VALUE=""
              if grep -q "^$VAR_NAME=" "$ENV_FILE"; then
                  EXISTING_VALUE=$(grep "^$VAR_NAME=" "$ENV_FILE" | cut -d'=' -f2- | tr -d '"')
              fi
              
              MANAGED_VALUES=$(cat "$STATE_FILE" 2>/dev/null || echo "")
              
              declare -A VALUE_SET
              for ITEM in $(echo "$EXISTING_VALUE" | tr ',' ' '); do
                  VALUE_SET["$ITEM"]=1
              done
              
              for ITEM in $(echo "$MANAGED_VALUES" | tr ',' ' '); do
                  if [[ -n "${VALUE_SET[$ITEM]}" ]]; then
                      unset VALUE_SET["$ITEM"]
                  fi
              done
              
              for ITEM in $(echo "$NEW_VALUE" | tr ',' ' '); do
                  VALUE_SET["$ITEM"]=1
              done
              
              UPDATED_VALUE=$(IFS=','; echo "${!VALUE_SET[*]}")
              
              if grep -q "^$VAR_NAME=" "$ENV_FILE"; then
                  sed -i "s|^$VAR_NAME=.*|$VAR_NAME=\"$UPDATED_VALUE\"|" "$ENV_FILE"
              else
                  echo "$VAR_NAME=\"$UPDATED_VALUE\"" >> "$ENV_FILE"
              fi
              
              echo "$NEW_VALUE" > "$STATE_FILE"
          }
          
          if [ "$CURRENT_ENV_CHECKSUM" != "$LAST_ENV_CHECKSUM" ] || [ "$CURRENT_CERTS_CHECKSUM" != "$LAST_CERTS_CHECKSUM" ]; then
              echo "🚀 Alteração detectada. Reiniciando containerd..."
              chroot /host /bin/sh -c 'systemctl restart containerd || kill -HUP $(pidof containerd)'
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
          optional: true
      - name: env-config
        configMap:
          name: env-config
          optional: true
      hostNetwork: true
      hostPID: true
