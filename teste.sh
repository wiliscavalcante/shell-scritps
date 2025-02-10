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
      - name: eks-node-config-agent
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
          echo "🔹 Iniciando EKS Node Config Agent..."

          CONFIG_MARKER="/host/etc/eks-node-configured"

          if [ "$FORCE_RECONFIGURE" = "false" ] && [ -f "$CONFIG_MARKER" ]; then
            echo "✅ Configuração já aplicada. Mantendo pod ativo..."
            sleep infinity
          fi

          echo "🚀 FORÇANDO RECONFIGURAÇÃO! (FORCE_RECONFIGURE=$FORCE_RECONFIGURE)"

          ## Etapa 1: Atualizando Variáveis de Ambiente
          echo "🔹 Etapa 1: Atualizando Variáveis de Ambiente..."
          chroot /host /bin/sh -c '
          ENV_FILE="/etc/environment"

          # Verifica se o arquivo existe, senão cria
          if [ ! -f "$ENV_FILE" ]; then
              echo "Criando $ENV_FILE"
              touch "$ENV_FILE"
          fi

          # Itera sobre as variáveis definidas no ConfigMap montado
          while IFS="=" read -r VAR_NAME VALUE; do
              if [ -z "$VAR_NAME" ] || [ -z "$VALUE" ]; then
                  echo "❌ Variável sem valor. Pulando..."
                  continue
              fi

              # Determina se é uma variável que suporta múltiplos valores (incremento)
              case "$VAR_NAME" in
                  NO_PROXY|no_proxy|PATH|LD_LIBRARY_PATH)
                      echo "🔹 Incrementando $VAR_NAME com valor: $VALUE"
                      if grep -q "^$VAR_NAME=" "$ENV_FILE"; then
                          sed -i "/^$VAR_NAME=/ s|$|,$VALUE|" "$ENV_FILE"
                      else
                          echo "$VAR_NAME=$VALUE" >> "$ENV_FILE"
                      fi
                      ;;
                  *)
                      echo "🔹 Criando ou substituindo variável única: $VAR_NAME=$VALUE"
                      sed -i "/^$VAR_NAME=/d" "$ENV_FILE"
                      echo "$VAR_NAME=$VALUE" >> "$ENV_FILE"
                      ;;
              esac
          done < /env-config/variables.list

          # Aplica as variáveis no ambiente
          source "$ENV_FILE"
          echo "✅ Variáveis de ambiente aplicadas!"
          '

          ## Etapa 2: Copiando Certificados
          echo "🔹 Etapa 2: Copiando Certificados..."
          CERT_DIR="/host/etc/pki/ca-trust/source/anchors"
          mkdir -p "$CERT_DIR"
          cp /certs/*.crt "$CERT_DIR/"

          chroot /host update-ca-trust extract
          echo "✅ Certificados instalados e atualizados!"

          ## Etapa 3: Reiniciando containerd
          echo "🔹 Etapa 3: Reiniciando containerd..."
          chroot /host /bin/sh -c '
          if command -v systemctl &> /dev/null; then
              systemctl restart containerd && echo "✅ containerd reiniciado com systemctl!" && exit 0
          fi
          
          kill -HUP $(pidof containerd) && echo "✅ containerd recarregado via HUP!" || echo "❌ Falha ao reiniciar containerd!"
          '

          if [ "$FORCE_RECONFIGURE" = "false" ]; then
            touch /host/etc/eks-node-configured
          fi

          echo "✅ Configuração finalizada!"
          
          sleep infinity
        volumeMounts:
        - name: host-root
          mountPath: /host
        - name: certs
          mountPath: /certs
        - name: env-config
          mountPath: /env-config
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
