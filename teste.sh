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

          CONFIG_MARKER="/host/etc/node-config-applied"

          # Se já estiver configurado e não forçar, mantém o pod rodando sem fazer nada
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

          # Se o arquivo de variáveis não existir, pula a etapa
          if [ ! -f "/env-config/variables.yaml" ]; then
              echo "❌ Arquivo de variáveis não encontrado. Pulando..."
          else
              # Itera sobre as variáveis definidas no ConfigMap montado
              yq e ". | to_entries | .[]" /env-config/variables.yaml | while read entry; do
                  VAR_NAME=$(echo "$entry" | yq e ".key" -)
                  MODE=$(echo "$entry" | yq e ".value.mode" -)
                  VALUE=$(echo "$entry" | yq e ".value.value" -)

                  if [ -z "$VAR_NAME" ] || [ -z "$VALUE" ]; then
                      echo "❌ Variável sem valor. Pulando..."
                      continue
                  fi

                  # Determina se deve incrementar ou substituir o valor
                  case "$MODE" in
                      append)
                          echo "🔹 Incrementando $VAR_NAME com valor: $VALUE"
                          if grep -q "^$VAR_NAME=" "$ENV_FILE"; then
                              sed -i "/^$VAR_NAME=/ s|$|,$VALUE|" "$ENV_FILE"
                          else
                              echo "$VAR_NAME=$VALUE" >> "$ENV_FILE"
                          fi
                          ;;
                      overwrite)
                          echo "🔹 Substituindo $VAR_NAME por: $VALUE"
                          sed -i "/^$VAR_NAME=/d" "$ENV_FILE"
                          echo "$VAR_NAME=$VALUE" >> "$ENV_FILE"
                          ;;
                      *)
                          echo "❌ Modo inválido ($MODE) para variável $VAR_NAME. Pulando..."
                          ;;
                  esac
              done
          fi

          # Aplica as variáveis no ambiente
          source "$ENV_FILE"
          echo "✅ Variáveis de ambiente aplicadas!"
          '

          ## Etapa 2: Copiando Certificados
          echo "🔹 Etapa 2: Copiando Certificados..."
          CERT_DIR="/host/etc/pki/ca-trust/source/anchors"
          mkdir -p "$CERT_DIR"
          cp /certs/*.crt "$CERT_DIR/" 2>/dev/null || echo "❌ Nenhum certificado encontrado para copiar."

          chroot /host update-ca-trust extract
          echo "✅ Certificados instalados e atualizados!"

          ## Etapa 3: Reiniciando containerd
          echo "🔹 Etapa 3: Reiniciando containerd..."
          chroot /host /bin/bash -c '
          if command -v systemctl &> /dev/null; then
              systemctl restart containerd && echo "✅ containerd reiniciado com systemctl!" && exit 0
          fi
          
          kill -HUP $(pidof containerd) && echo "✅ containerd recarregado via HUP!" || echo "❌ Falha ao reiniciar containerd!"
          '

          # Marca a configuração como aplicada
          if [ "$FORCE_RECONFIGURE" = "false" ]; then
            touch /host/etc/node-config-applied
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
      echo "🔹 Aplicando variáveis de ambiente do ConfigMap..."

chroot /host /bin/sh -c '
ENV_FILE="/etc/environment"
CONFIG_FILE="/host/env-config/variables.yaml"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "❌ ERRO: Arquivo de configuração não encontrado: $CONFIG_FILE"
    exit 1
fi

# Extrai todas as variáveis definidas no YAML
awk "/:/ {print \$1}" "$CONFIG_FILE" | sed "s/://g" | while read -r VAR_NAME; do
    MODE=$(awk -v var="$VAR_NAME" "/^$VAR_NAME:/,/mode:/ {if (\$1 == \"mode:\") print \$2}" "$CONFIG_FILE" | tr -d '\"')
    VALUE=$(awk -v var="$VAR_NAME" "/^$VAR_NAME:/,/value:/ {if (\$1 == \"value:\") print \$2}" "$CONFIG_FILE" | tr -d '\"')

    if [ -z "$MODE" ] || [ -z "$VALUE" ]; then
        echo "❌ ERRO: Modo ou valor ausente para $VAR_NAME. Pulando..."
        continue
    fi

    if [ "$MODE" = "overwrite" ]; then
        # Sobrescreve ou cria a variável
        if grep -q "^$VAR_NAME=" "$ENV_FILE"; then
            sed -i "s|^$VAR_NAME=.*|$VAR_NAME=\"$VALUE\"|" "$ENV_FILE"
            echo "✅ Substituído valor de $VAR_NAME: $(grep "^$VAR_NAME=" $ENV_FILE)"
        else
            echo "$VAR_NAME=\"$VALUE\"" >> "$ENV_FILE"
            echo "✅ Criada variável: $VAR_NAME=\"$VALUE\""
        fi

    elif [ "$MODE" = "append" ]; then
        # Incrementa valores sem remover os existentes
        if grep -q "^$VAR_NAME=" "$ENV_FILE"; then
            CURRENT_VALUE=$(grep "^$VAR_NAME=" "$ENV_FILE" | cut -d'=' -f2 | tr -d '"')

            if echo "$CURRENT_VALUE" | grep -q "$VALUE"; then
                echo "🔹 Valor '$VALUE' já presente em $VAR_NAME. Nenhuma alteração necessária."
            else
                NEW_VALUE="$CURRENT_VALUE,$VALUE"
                NEW_VALUE=$(echo "$NEW_VALUE" | sed 's/^,//;s/,,/,/') # Remove múltiplas vírgulas
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

