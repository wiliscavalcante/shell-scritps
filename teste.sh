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
          echo "🔹 Iniciando DaemonSet de Fix de Nexus no EKS..."
          
          CONFIG_MARKER="/host/etc/nexus-configured"
 
          if [ "$FORCE_RECONFIGURE" = "false" ] && [ -f "$CONFIG_MARKER" ]; then
            echo "✅ Configuração já aplicada. Mantendo pod ativo..."
            exec sleep infinity
          fi
 
          echo "🚀 FORÇANDO RECONFIGURAÇÃO! (FORCE_RECONFIGURE=$FORCE_RECONFIGURE)"
          
          echo "🔹 Etapa 1: Aplicando variáveis de ambiente do ConfigMap..."
          chroot /host /bin/sh -c '
          ENV_FILE="/etc/environment"
          CONFIG_FILE="/host/env-config/variables.yaml"
 
          if [ ! -f "$CONFIG_FILE" ]; then
              echo "❌ ERRO: Arquivo de configuração não encontrado: $CONFIG_FILE"
              exit 1
          fi
 
          awk "/^[a-zA-Z_]+:$/ {var=$1; sub(":", "", var); getline; mode=$2; getline; value=$2; gsub("\"", "", value); print var, mode, value;}" "$CONFIG_FILE" | while read -r VAR_NAME MODE VALUE; do
              if [ -z "$MODE" ] || [ -z "$VALUE" ]; then
                  echo "❌ ERRO: Modo ou valor ausente para $VAR_NAME. Pulando..."
                  continue
              fi
 
              if [ "$MODE" = "overwrite" ]; then
                  if grep -q "^$VAR_NAME=" "$ENV_FILE"; then
                      sed -i "s|^$VAR_NAME=.*|$VAR_NAME=\"$VALUE\"|" "$ENV_FILE"
                      echo "✅ Substituído valor de $VAR_NAME: $(grep "^$VAR_NAME=" $ENV_FILE)"
                  else
                      echo "$VAR_NAME=\"$VALUE\"" >> "$ENV_FILE"
                      echo "✅ Criada variável: $VAR_NAME=\"$VALUE\""
                  fi
              elif [ "$MODE" = "append" ]; then
                  if grep -q "^$VAR_NAME=" "$ENV_FILE"; then
                      CURRENT_VALUE=$(grep "^$VAR_NAME=" "$ENV_FILE" | cut -d'=' -f2 | tr -d '"')
                      if echo "$CURRENT_VALUE" | grep -q "$VALUE"; then
                          echo "🔹 Valor '$VALUE' já presente em $VAR_NAME. Nenhuma alteração necessária."
                      else
                          NEW_VALUE="$CURRENT_VALUE,$VALUE"
                          NEW_VALUE=$(echo "$NEW_VALUE" | sed 's/^,//;s/,,/,/')
                          sed -i "s|^$VAR_NAME=.*|$VAR_NAME=\"$NEW_VALUE\"|" "$ENV_FILE"
                          echo "✅ Incrementado valor em $VAR_NAME: $(grep "^$VAR_NAME=" $ENV_FILE)"
                      fi
                  else
                      echo "$VAR_NAME=\"$VALUE\"" >> "$ENV_FILE"
                      echo "✅ Criada variável: $VAR_NAME=\"$VALUE\""
                  fi
              else
                  echo "❌ ERRO: Modo inválido para $VAR_NAME: $MODE"
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
