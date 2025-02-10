apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: fix-nexus-config
  namespace: kube-system
spec:
  selector:
    matchLabels:
      name: fix-nexus-config
  template:
    metadata:
      labels:
        name: fix-nexus-config
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
      - name: fix-nexus
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
            while true; do sleep 3600; done
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
 
          echo "🔹 Etapa 2: Copiando certificado do Nexus..."
          if [ ! -f "/certs/nexus-ca.crt" ]; then
            echo "❌ ERRO: Certificado não encontrado no pod!"
            exit 1
          fi
 
          mkdir -p /host/etc/pki/ca-trust/source/anchors/
          cp /certs/nexus-ca.crt /host/etc/pki/ca-trust/source/anchors/
 
          chroot /host update-ca-trust extract
          echo "✅ Certificado instalado e atualizado!"
 
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
 
          while true; do sleep 3600; done
        volumeMounts:
        - name: host-root
          mountPath: /host
        - name: certs
          mountPath: /certs
      volumes:
      - name: host-root
        hostPath:
          path: /
      - name: certs
        configMap:
          name: nexus-cert
      hostNetwork: true
      hostPID: true
