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
          echo "🔹 Iniciando DaemonSet de configuração do EKS..."
          
          CONFIG_MARKER="/host/etc/config-applied"
 
          if [ "$FORCE_RECONFIGURE" = "false" ] && [ -f "$CONFIG_MARKER" ]; then
            echo "✅ Configuração já aplicada. Mantendo pod ativo..."
            while true; do sleep 3600; done
          fi
 
          echo "🚀 FORÇANDO RECONFIGURAÇÃO! (FORCE_RECONFIGURE=$FORCE_RECONFIGURE)"
          
          echo "🔹 Etapa 1: Aplicando variáveis de ambiente..."
          chroot /host /bin/sh -c '
          ENV_FILE="/etc/environment"
          CONFIG_MAP_DIR="/env-config"
          
          for VAR in $(ls $CONFIG_MAP_DIR); do
              VALUE=$(cat "$CONFIG_MAP_DIR/$VAR")
              
              if ! grep -q "^$VAR=" "$ENV_FILE"; then
                  echo "$VAR=\"$VALUE\"" >> "$ENV_FILE"
                  echo "✅ Criada variável: $VAR=\"$VALUE\""
                  continue
              fi
              
              if [ "$VAR" = "NO_PROXY" ] || [ "$VAR" = "no_proxy" ]; then
                  CURRENT_VALUE=$(grep "^$VAR=" "$ENV_FILE" | cut -d'=' -f2 | tr -d '"')
                  
                  if echo "$CURRENT_VALUE" | grep -q "$VALUE"; then
                      echo "🔹 Valor '$VALUE' já presente em $VAR. Nenhuma alteração necessária."
                  else
                      NEW_VALUE="$CURRENT_VALUE,$VALUE"
                      NEW_VALUE=$(echo "$NEW_VALUE" | sed 's/^,//;s/,,/,/')
                      sed -i "s|^$VAR=.*|$VAR=\"$NEW_VALUE\"|" "$ENV_FILE"
                      echo "✅ Incrementado valor em $VAR: $(grep "^$VAR=" $ENV_FILE)"
                  fi
                  continue
              fi
              
              sed -i "s|^$VAR=.*|$VAR=\"$VALUE\"|" "$ENV_FILE"
              echo "✅ Substituído valor de $VAR: $(grep "^$VAR=" $ENV_FILE)"
          done
          
          source "$ENV_FILE"
          '
          
          echo "✅ Variáveis aplicadas com sucesso!"

          echo "🔹 Etapa 2: Copiando certificados..."
          if [ "$(ls /certs | wc -l)" -eq 0 ]; then
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
            touch /host/etc/config-applied
          fi
 
          echo "✅ Configuração finalizada!"
 
          while true; do sleep 3600; done
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
