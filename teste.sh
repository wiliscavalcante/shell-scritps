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
          value: "true"
        command: ["/bin/sh", "-c"]
        args:
        - |
          echo "🔹 Iniciando DaemonSet para configuração no EKS..."
          
          CONFIG_MARKER="/host/etc/nexus-configured"
          ENV_FILE="/etc/environment"
          CONFIG_DIR="/env-config"
 
          if [ "$FORCE_RECONFIGURE" = "false" ] && [ -f "$CONFIG_MARKER" ]; then
            echo "✅ Configuração já aplicada. Mantendo pod ativo..."
            exec sleep infinity
          fi
 
          echo "🚀 Aplicando variáveis de ambiente do ConfigMap..."
 
          chroot /host /bin/sh -c '
          if [ ! -d "$CONFIG_DIR" ]; then
              echo "❌ ERRO: Diretório de configuração não encontrado: $CONFIG_DIR"
              exit 1
          fi
 
          for VAR_FILE in $(ls "$CONFIG_DIR"); do
              VAR_NAME="$VAR_FILE"
              MODE=$(awk -F": " "/mode:/ {print \$2}" "$CONFIG_DIR/$VAR_FILE")
              VALUE=$(awk -F": " "/value:/ {print \$2}" "$CONFIG_DIR/$VAR_FILE")
 
              if [ -z "$MODE" ] || [ -z "$VALUE" ]; then
                  echo "❌ ERRO: Modo ou valor ausente para $VAR_NAME. Pulando..."
                  continue
              fi
 
              if grep -q "^$VAR_NAME=" "$ENV_FILE"; then
                  if [ "$MODE" = "append" ]; then
                      sed -i "/^$VAR_NAME=/ s|\$|,$VALUE|" "$ENV_FILE"
                      sed -i "s|,,|,|g" "$ENV_FILE" # Remove múltiplas vírgulas
                      echo "✅ Incrementado valor em $VAR_NAME: $(grep "^$VAR_NAME=" $ENV_FILE)"
                  else
                      sed -i "s|^$VAR_NAME=.*|$VAR_NAME=\"$VALUE\"|" "$ENV_FILE"
                      echo "✅ Substituído valor de $VAR_NAME: $(grep "^$VAR_NAME=" $ENV_FILE)"
                  fi
              else
                  echo "$VAR_NAME=\"$VALUE\"" >> "$ENV_FILE"
                  echo "✅ Criada nova variável: $VAR_NAME=\"$VALUE\""
              fi
          done
 
          source "$ENV_FILE"
          echo "✅ Todas as variáveis aplicadas com sucesso!"
          '
 
          echo "🔹 Etapa 2: Copiando certificados do Nexus..."
          if [ "$(ls -A /certs | wc -l)" -eq 0 ]; then
            echo "❌ ERRO: Nenhum certificado encontrado no pod!"
            exit 1
          fi
 
          mkdir -p /host/etc/pki/ca-trust/source/anchors/
          cp /certs/* /host/etc/pki/ca-trust/source/anchors/
 
          chroot /host update-ca-trust extract
          echo "✅ Certificados instalados e atualizados!"
 
          echo "🔹 Etapa 3: Reiniciando containerd..."
          chroot /host /bin/sh -c '
          if command -v systemctl &> /dev/null; then
              systemctl restart containerd && echo "✅ containerd reiniciado com systemctl!" && exit 0
          fi
          
          kill -HUP $(pidof containerd) && echo "✅ containerd recarregado via HUP!" || echo "❌ Falha ao reiniciar containerd!"
          '
 
          if [ "$FORCE_RECONFIGURE" = "false" ]; then
            touch /host/etc/nexus-configured
          fi
 
          echo "✅ Configuração finalizada!"
 
          exec sleep infinity
        volumeMounts:
        - name: host-root
          mountPath: /host
        - name: certs
          mountPath: /certs
        - name: env-config
          mountPath: /env-config
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
