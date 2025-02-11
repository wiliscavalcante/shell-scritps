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
          echo "🔹 Criando script temporário para atualização de variáveis..."
          cat << 'EOF' > /host/tmp/update_env.sh
          #!/bin/sh
          ENV_FILE="/etc/environment"
          CONFIG_DIR="/env-config"

          for VAR_FILE in $(ls "$CONFIG_DIR"); do
              VAR_NAME="$VAR_FILE"
              MODE=$(awk -F": " "/mode:/ {print \$2}" "$CONFIG_DIR/$VAR_FILE")
              VALUE=$(awk -F": " "/value:/ {print \$2}" "$CONFIG_DIR/$VAR_FILE" | tr -d '"') # Remove aspas extras

              if [ -z "$MODE" ] || [ -z "$VALUE" ]; then
                  echo "❌ ERRO: Modo ou valor ausente para $VAR_NAME. Pulando..."
                  continue
              fi

              if grep -q "^$VAR_NAME=" "$ENV_FILE"; then
                  if [ "$MODE" = "append" ]; then
                      if grep -q ",$VALUE" "$ENV_FILE"; then
                          echo "🔹 Valor '$VALUE' já presente em $VAR_NAME. Nenhuma alteração necessária."
                      else
                          sed -i "/^$VAR_NAME=/ s|\$|,$VALUE|" "$ENV_FILE"
                          sed -i "s|^$VAR_NAME=,|$VAR_NAME=|" "$ENV_FILE" # Remove vírgula inicial
                          sed -i 's|,\s*|,|g' "$ENV_FILE" # Remove espaços extras entre valores
                          echo "✅ Incrementado valor em $VAR_NAME: $(grep "^$VAR_NAME=" $ENV_FILE)"
                      fi
                  else
                      sed -i "s|^$VAR_NAME=.*|$VAR_NAME=$VALUE|" "$ENV_FILE"
                      echo "✅ Substituído valor de $VAR_NAME: $(grep "^$VAR_NAME=" $ENV_FILE)"
                  fi
              else
                  echo "$VAR_NAME=$VALUE" >> "$ENV_FILE"
                  echo "✅ Criada nova variável: $VAR_NAME=$VALUE"
              fi
          done

          source "$ENV_FILE"
          echo "✅ Todas as variáveis aplicadas com sucesso!"
          EOF

          # Torna o script executável
          chmod +x /host/tmp/update_env.sh

          # Executa o script dentro do chroot
          chroot /host /bin/sh /tmp/update_env.sh

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
---
echo "🔹 Criando script temporário para atualização de variáveis..."
cat << 'EOF' > /host/tmp/update_env.sh
#!/bin/sh
ENV_FILE="/etc/environment"
CONFIG_DIR="/env-config"

for VAR_FILE in $(ls "$CONFIG_DIR"); do
    VAR_NAME="$VAR_FILE"
    MODE=$(grep "mode:" "$CONFIG_DIR/$VAR_FILE" | cut -d':' -f2 | tr -d ' ')
    VALUE=$(grep "value:" "$CONFIG_DIR/$VAR_FILE" | cut -d':' -f2 | tr -d ' ' | tr -d '"')

    if [ -z "$MODE" ] || [ -z "$VALUE" ]; then
        echo "❌ ERRO: Modo ou valor ausente para $VAR_NAME. Pulando..."
        continue
    fi

    if grep -q "^$VAR_NAME=" "$ENV_FILE"; then
        if [ "$MODE" = "append" ]; then
            # Verifica corretamente se o valor já está presente
            EXISTING_VALUE=$(grep "^$VAR_NAME=" "$ENV_FILE" | cut -d'=' -f2 | tr -d '"')
            
            # Se o valor ainda não está presente, adicionamos corretamente
            if echo "$EXISTING_VALUE" | grep -q -w "$VALUE"; then
                echo "🔹 Valor '$VALUE' já presente em $VAR_NAME. Nenhuma alteração necessária."
            else
                sed -i "/^$VAR_NAME=/ s|\$|,$VALUE|" "$ENV_FILE"
                sed -i "s|^$VAR_NAME=,|$VAR_NAME=|" "$ENV_FILE" # Remove vírgula inicial
                sed -i 's|,\s*|,|g' "$ENV_FILE" # Remove espaços extras entre valores
                echo "✅ Incrementado valor em $VAR_NAME: $(grep "^$VAR_NAME=" $ENV_FILE)"
            fi
        else
            sed -i "s|^$VAR_NAME=.*|$VAR_NAME=$VALUE|" "$ENV_FILE"
            echo "✅ Substituído valor de $VAR_NAME: $(grep "^$VAR_NAME=" $ENV_FILE)"
        fi
    else
        echo "$VAR_NAME=$VALUE" >> "$ENV_FILE"
        echo "✅ Criada nova variável: $VAR_NAME=$VALUE"
    fi
done

echo "✅ Todas as variáveis aplicadas com sucesso!"
EOF

# Torna o script executável
chmod +x /host/tmp/update_env.sh

# Executa o script dentro do chroot
chroot /host /bin/sh /tmp/update_env.sh
