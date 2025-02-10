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
          
          echo "🔹 Etapa 1: Atualizando NO_PROXY..."
          chroot /host /bin/sh -c '
          ENV_FILE="/etc/environment"
          NEXUS_DOMAIN=".agribusiness-brain.us.experian.eeca"
 
          if ! grep -q "$NEXUS_DOMAIN" "$ENV_FILE"; then
              sed -i "/NO_PROXY=/ s|$|,$NEXUS_DOMAIN|" "$ENV_FILE"
              sed -i "/no_proxy=/ s|$|,$NEXUS_DOMAIN|" "$ENV_FILE"
          fi
          source "$ENV_FILE"
          echo "✅ NO_PROXY atualizado: $(grep NO_PROXY $ENV_FILE)"
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
