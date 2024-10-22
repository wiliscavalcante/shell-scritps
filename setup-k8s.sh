# #!/bin/bash
 
# # Função para registrar logs das ações do script
# log() {
#   echo "$(date +'%Y-%m-%d %H:%M:%S') - $1"
# }
 
# # Passo 1: Criar o arquivo de configuração do proxy em /etc/profile.d/
# log "Criando o arquivo /etc/profile.d/proxy.sh"
 
# if [ ! -f /etc/profile.d/proxy.sh ] || ! grep -q "proxy-on" /etc/profile.d/proxy.sh; then
# sudo tee /etc/profile.d/proxy.sh > /dev/null << 'EOF'
# function urlencode() {
#     local encoded=`/usr/bin/python -c "import urllib; import sys; print urllib.quote(sys.argv[1])" $1`
#     echo $encoded
# }

# function proxy-off() {
#     unset proxy http_proxy HTTP_PROXY https_proxy HTTPS_PROXY empresa_proxy
# }

# function proxy-on() {
#     username=$1
#     if [ -z $username ]; then
#         proxy=http://spobrproxy.empresa.intranet:3128
#     else
#         echo "Please, input your password."
#         read -s password
#         encoded_password=$(urlencode $password)
#         proxy=http://$username:$encoded_password@spobrproxy.empresa.intranet:3128
#     fi
#     http_proxy=$proxy
#     HTTP_PROXY=$proxy
#     https_proxy=$proxy
#     HTTPS_PROXY=$proxy
#     export proxy http_proxy https_proxy HTTP_PROXY HTTPS_PROXY
# }
# function no_proxy(){
#   no_proxy="dockerhub.datalabempresaexperian.com.br,registry.datalabempresaexperian.com.br,pypi.datalabempresaexperian.com.br,maven.datalabempresaexperian.com.br,packages.datalabempresaexperian.com.br,10.*"
#   export no_proxy
# }
# if [ -z ${no_proxy} ]
# then
#   no_proxy
# fi
# EOF
 
# sudo chmod +x /etc/profile.d/proxy.sh
# log "Arquivo /etc/profile.d/proxy.sh criado e configurado."
# else
# log "Arquivo /etc/profile.d/proxy.sh já existe e está configurado."
# fi
 
# if ! env | grep -q "HTTP_PROXY"; then
# log "Carregando o script /etc/profile.d/proxy.sh no ambiente."
# source /etc/profile.d/proxy.sh
# else
#   log "Proxy já configurado no ambiente."
# fi
 
# # Passo 2: Desativar o swap, se estiver ativo
# if free | awk '/^Swap:/ {exit !$2}'; then
#   log "Swap ativo. Desativando swap..."
  
#   sudo swapoff -a
#   sudo sed -i.bak '/swap/d' /etc/fstab
  
#   log "Swap desativado e removido do /etc/fstab."
# else
#   log "Swap já está desativado."
# fi

# # Passo 3: Habilitar o encaminhamento de pacotes IPv4, se necessário
# log "Verificando o encaminhamento de pacotes IPv4"

# if ! sysctl net.ipv4.ip_forward | grep -q "1"; then
#   log "Habilitando net.ipv4.ip_forward"

#   sudo tee /etc/sysctl.d/k8s.conf > /dev/null << 'EOF'
# net.ipv4.ip_forward = 1
# EOF

#   sudo sysctl --system
#   log "Encaminhamento de pacotes IPv4 habilitado."
# else
#   log "Encaminhamento de pacotes IPv4 já está habilitado."
# fi

# # Passo 4: Carregar o módulo br_netfilter
# log "Verificando se o módulo br_netfilter está carregado"
# if ! lsmod | grep -q br_netfilter; then
#   log "Carregando o módulo br_netfilter"
#   sudo modprobe br_netfilter
  
#   # Tornar persistente
#   echo "br_netfilter" | sudo tee /etc/modules-load.d/br_netfilter.conf
#   log "Módulo br_netfilter carregado e configurado para persistência."
# else
#   log "Módulo br_netfilter já está carregado."
# fi

 
# # Passo 5: Configurar nameservers em /etc/resolv.conf
# log "Editando /etc/resolv.conf para configurar nameservers"
 
# if grep -q "^nameserver 127.0.0.1" /etc/resolv.conf; then
#   log "Comentando o nameserver 127.0.0.1"
#   sudo sed -i.bak 's/^nameserver 127.0.0.1/# &/' /etc/resolv.conf
# fi
 
# # Adicionar novos nameservers se não estiverem presentes
# for ns in 10.96.215.13 10.96.216.4 10.96.216.20; do
#   if ! grep -q "nameserver $ns" /etc/resolv.conf; then
#     log "Adicionando nameserver $ns"
#     echo "nameserver $ns" | sudo tee -a /etc/resolv.conf
#   fi
# done
 
# log "Configuração do /etc/resolv.conf concluída."
 
# # Passo 6: Configurar SELinux para modo permissivo, se necessário
# log "Verificando o status do SELinux"
 
# selinux_status=$(getenforce)
# if [ "$selinux_status" = "Disabled" ]; then
#   log "SELinux já está desativado."
# elif [ "$selinux_status" = "Enforcing" ]; then
#   log "Alterando SELinux para modo permissivo."
  
#   sudo setenforce 0
#   sudo sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config
  
#   log "SELinux foi alterado para modo permissivo."
# else
#   log "SELinux já está em modo permissivo."
# fi
 
# # Passo 6: Configurar o repositório Kubernetes, se necessário
# log "Verificando a configuração do repositório Kubernetes"

# repo_file="/etc/yum.repos.d/kubernetes.repo"
# expected_baseurl="https://pkgs.k8s.io/core:/stable:/v1.31/rpm/"

# if [ ! -f "$repo_file" ] || ! grep -q "$expected_baseurl" "$repo_file"; then
#   log "Configurando o repositório Kubernetes."
  
#   sudo tee "$repo_file" > /dev/null << 'EOF'
# [kubernetes]
# name=Kubernetes
# baseurl=https://pkgs.k8s.io/core:/stable:/v1.31/rpm/
# enabled=1
# gpgcheck=1
# gpgkey=https://pkgs.k8s.io/core:/stable:/v1.31/rpm/repodata/repomd.xml.key
# exclude=kubelet kubeadm kubectl cri-tools kubernetes-cni
# EOF

#   log "Repositório Kubernetes configurado."
# else
#   log "Repositório Kubernetes já está configurado corretamente."
# fi
 
# # Passo 7: Configurar o repositório CRI-O, se necessário
# log "Verificando a configuração do repositório CRI-O"

# cri_o_repo_file="/etc/yum.repos.d/cri-o.repo"
# cri_o_expected_baseurl="https://pkgs.k8s.io/addons:/cri-o:/stable:/v1.31/rpm/"

# if [ ! -f "$cri_o_repo_file" ] || ! grep -q "$cri_o_expected_baseurl" "$cri_o_repo_file"; then
#   log "Configurando o repositório CRI-O."
  
#   sudo tee "$cri_o_repo_file" > /dev/null << EOF
# [cri-o]
# name=CRI-O
# baseurl=https://pkgs.k8s.io/addons:/cri-o:/stable:/v1.31/rpm/
# enabled=1
# gpgcheck=1
# gpgkey=https://pkgs.k8s.io/addons:/cri-o:/stable:/v1.31/rpm/repodata/repomd.xml.key
# EOF

#   log "Repositório CRI-O configurado."
# else
#   log "Repositório CRI-O já está configurado corretamente."
# fi
 
# # Passo 8: Instalar dependências de pacotes, se necessário
# log "Verificando se o pacote 'container-selinux' está instalado"
 
# if ! rpm -q container-selinux > /dev/null 2>&1; then
#   log "Instalando o pacote 'container-selinux'."
#   sudo dnf install -y container-selinux
#   log "Pacote 'container-selinux' instalado."
# else
#   log "Pacote 'container-selinux' já está instalado."
# fi
 
# # Passo 9: Configurar o repositório ZFS, se necessário
# log "Verificando a configuração do repositório ZFS"
 
# zfs_repo_file="/etc/yum.repos.d/zfs.repo"
# zfs_expected_baseurl="https://nexus.datalabsserasexperian.com.br/repository/zfsonlinux"
 
# if [ ! -f "$zfs_repo_file" ] || ! grep -q "$zfs_expected_baseurl" "$zfs_repo_file"; then
#   log "Configurando o repositório ZFS."
  
#   sudo tee "$zfs_repo_file" > /dev/null << 'EOF'
# [zfs-kmod]
# # original repo http://download.zfsonlinux.org/epel/
# name=ZFS on Linux for EL$releasever - kmod
# baseurl=https://nexus.datalabempresaexperian.com.br/repository/zfsonlinux/$releasever/kmod/$basearch/
# enabled=1
# metadata_expire=7d
# gpgcheck=0
# EOF
 
#   log "Repositório ZFS configurado."
# else
#   log "Repositório ZFS já está configurado corretamente."
# fi
 
# # Instalar o pacote ZFS, se necessário
# if ! rpm -q zfs > /dev/null 2>&1; then
#   log "Instalando o pacote ZFS."
#   sudo dnf install -y zfs
#   log "Pacote ZFS instalado."
# else
#   log "Pacote ZFS já está instalado."
# fi
 
# # Configurar o carregamento automático dos módulos br_netfilter e zfs
# log "Configurando o carregamento automático dos módulos br_netfilter e zfs"
 
# # Configurar o carregamento automático do módulo br_netfilter
# if [ ! -f /etc/modules-load.d/br_netfilter.conf ]; then
#   echo "br_netfilter" | sudo tee /etc/modules-load.d/br_netfilter.conf
#   log "Módulo br_netfilter configurado para carregamento automático."
# else
#   log "Módulo br_netfilter já está configurado para carregamento automático."
# fi
 
# # Configurar o carregamento automático do módulo zfs
# if [ ! -f /etc/modules-load.d/zfs.conf ]; then
#   echo "zfs" | sudo tee /etc/modules-load.d/zfs.conf
#   log "Módulo zfs configurado para carregamento automático."
# else
#   log "Módulo zfs já está configurado para carregamento automático."
# fi
 
# # Passo 10: Criar o pool ZFS 'crio-pool' no disco /dev/sda usando caminho persistente
# log "Criando o pool ZFS 'crio-pool' no disco /dev/sda"
 
# persistent_path=$(readlink -f /dev/sda)
 
# if [ -z "$persistent_path" ]; then
#   log "Erro ao identificar o caminho persistente para /dev/sda."
#   exit 1
# fi
 
# if sudo zpool list | grep -q "crio-pool"; then
#   log "O pool ZFS 'crio-pool' já existe."
# else
#   sudo zpool create crio-pool "$persistent_path"
#   log "Pool ZFS 'crio-pool' criado com sucesso."
# fi
 
# # Passo 11: Instalar o CRI-O
# log "Instalando o CRI-O e configurando para usar o pool ZFS"
 
# sudo dnf install -y cri-o
# sudo systemctl enable crio
# log "CRI-O instalado."
 
# # Configurar o CRI-O para usar o pool ZFS
# zfs_mountpoint=$(sudo zfs get mountpoint -H -o value crio-pool)
 
# if [ -z "$zfs_mountpoint" ]; then
#   log "Erro ao identificar o ponto de montagem do pool ZFS 'crio-pool'."
#   exit 1
# fi
 
# sudo tee /etc/crio/crio.conf > /dev/null << EOF
# [storage]
# root = "$zfs_mountpoint"
# runroot = "/run/crio"
# driver = "overlay"
# EOF
 
# log "Configuração do CRI-O concluída. Reiniciando o CRI-O."
 
# sudo systemctl restart crio
# log "Serviço CRI-O reiniciado."
 
# # Passo 12: Instalar kubelet, kubeadm e kubectl
# log "Instalando kubelet, kubeadm, e kubectl"
 
# if ! rpm -q kubelet kubeadm kubectl > /dev/null 2>&1; then
#   sudo dnf install -y kubelet kubeadm kubectl --disableexcludes=kubernetes
#   log "Pacotes kubelet, kubeadm e kubectl instalados."
# else
#   log "Pacotes kubelet, kubeadm e kubectl já estão instalados."
# fi
 
# # Habilitar e iniciar o serviço kubelet
# log "Habilitando e iniciando o serviço kubelet"
# sudo systemctl enable --now kubelet

# # Habilitar proxy no CRIO
# log "Habilitando proxy no crio"

# mkdir -p /etc/systemd/system/crio.service.d
# sudo tee /etc/systemd/system/crio.service.d/proxy.conf > /dev/null << EOF
# [Service]
# Environment="HTTP_PROXY=http://spobrproxy.empresa.intranet:3128"
# Environment="HTTPS_PROXY=http://spobrproxy.empresa.intranet:3128"
# Environment="NO_PROXY=localhost,127.0.0.1"
# EOF


# log "Serviço kubelet habilitado e iniciado."
#!/bin/bash

# Função para registrar logs das ações do script
log() {
  echo "$(date +'%Y-%m-%d %H:%M:%S') - $1"
}

# Passo 1: Criar o arquivo de configuração do proxy em /etc/profile.d/
log "Criando o arquivo /etc/profile.d/proxy.sh"

if [ ! -f /etc/profile.d/proxy.sh ] || ! grep -q "proxy-on" /etc/profile.d/proxy.sh; then
  sudo tee /etc/profile.d/proxy.sh > /dev/null << 'EOF'
function urlencode() {
    local encoded=/usr/bin/python -c "import urllib; import sys; print urllib.quote(sys.argv[1])" $1
    echo $encoded
}

function proxy-off() {
    unset proxy http_proxy HTTP_PROXY https_proxy HTTPS_PROXY empresa_proxy
}

function proxy-on() {
    username=$1
    if [ -z $username ]; then
        proxy=http://proxy.seu_dominio.intranet:3128
    else
        echo "Please, input your password."
        read -s password
        encoded_password=$(urlencode $password)
        proxy=http://$username:$encoded_password@proxy.seu_dominio.intranet:3128
    fi
    http_proxy=$proxy
    HTTP_PROXY=$proxy
    https_proxy=$proxy
    HTTPS_PROXY=$proxy
    export proxy http_proxy https_proxy HTTP_PROXY HTTPS_PROXY
}

function no_proxy(){
  no_proxy="dockerhub.seu_dominio.com.br,registry.seu_dominio.com.br,pypi.seu_dominio.com.br,maven.seu_dominio.com.br,packages.seu_dominio.com.br,10.*"
  export no_proxy
}

if [ -z ${no_proxy} ]; then
  no_proxy
fi
EOF

  sudo chmod +x /etc/profile.d/proxy.sh
  log "Arquivo /etc/profile.d/proxy.sh criado e configurado."
else
  log "Arquivo /etc/profile.d/proxy.sh já existe e está configurado."
fi

if ! env | grep -q "HTTP_PROXY"; then
  log "Carregando o script /etc/profile.d/proxy.sh no ambiente."
  source /etc/profile.d/proxy.sh
else
  log "Proxy já configurado no ambiente."
fi

# Passo 2: Desativar o swap, se estiver ativo
if free | awk '/^Swap:/ {exit !$2}'; then
  log "Swap ativo. Desativando swap..."
  
  sudo swapoff -a
  sudo sed -i.bak '/swap/d' /etc/fstab
  
  log "Swap desativado e removido do /etc/fstab."
else
  log "Swap já está desativado."
fi

# Passo 3: Habilitar o encaminhamento de pacotes IPv4, se necessário
log "Verificando o encaminhamento de pacotes IPv4"

if ! sysctl net.ipv4.ip_forward | grep -q "1"; then
  log "Habilitando net.ipv4.ip_forward"

  sudo tee /etc/sysctl.d/k8s.conf > /dev/null << 'EOF'
net.ipv4.ip_forward = 1
EOF

  sudo sysctl --system
  log "Encaminhamento de pacotes IPv4 habilitado."
else
  log "Encaminhamento de pacotes IPv4 já está habilitado."
fi

# Passo 4: Carregar o módulo br_netfilter
log "Verificando se o módulo br_netfilter está carregado"
if ! lsmod | grep -q br_netfilter; then
  log "Carregando o módulo br_netfilter"
  sudo modprobe br_netfilter
  
  # Tornar persistente
  echo "br_netfilter" | sudo tee /etc/modules-load.d/br_netfilter.conf
  log "Módulo br_netfilter carregado e configurado para persistência."
else
  log "Módulo br_netfilter já está carregado."
fi

# Passo 5: Configurar nameservers em /etc/resolv.conf
log "Editando /etc/resolv.conf para configurar nameservers"

if grep -q "^nameserver 127.0.0.1" /etc/resolv.conf; then
  log "Comentando o nameserver 127.0.0.1"
  sudo sed -i.bak 's/^nameserver 127.0.0.1/# &/' /etc/resolv.conf
fi

# Adicionar novos nameservers se não estiverem presentes
for ns in 10.96.215.13 10.96.216.4 10.96.216.20; do
  if ! grep -q "nameserver $ns" /etc/resolv.conf; then
    log "Adicionando nameserver $ns"
    echo "nameserver $ns" | sudo tee -a /etc/resolv.conf
  fi
done

log "Configuração do /etc/resolv.conf concluída."

# Passo 6: Configurar o repositório Kubernetes, se necessário
log "Verificando a configuração do repositório Kubernetes"

repo_file="/etc/yum.repos.d/kubernetes.repo"
expected_baseurl="https://pkgs.k8s.io/core:/stable:/v1.31/rpm/"

if [ ! -f "$repo_file" ] || ! grep -q "$expected_baseurl" "$repo_file"; then
  log "Configurando o repositório Kubernetes."
  
  sudo tee "$repo_file" > /dev/null << 'EOF'
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.31/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.31/rpm/repodata/repomd.xml.key
exclude=kubelet kubeadm kubectl cri-tools kubernetes-cni
EOF

  log "Repositório Kubernetes configurado."
else
  log "Repositório Kubernetes já está configurado corretamente."
fi

# Passo 7: Configurar o repositório CRI-O, se necessário
log "Verificando a configuração do repositório CRI-O"

cri_o_repo_file="/etc/yum.repos.d/cri-o.repo"
cri_o_expected_baseurl="https://pkgs.k8s.io/addons:/cri-o:/stable:/v1.31/rpm/"

if [ ! -f "$cri_o_repo_file" ] || ! grep -q "$cri_o_expected_baseurl" "$cri_o_repo_file"; then
  log "Configurando o repositório CRI-O."
  
  sudo tee "$cri_o_repo_file" > /dev/null << EOF
[cri-o]
name=CRI-O
baseurl=https://pkgs.k8s.io/addons:/cri-o:/stable:/v1.31/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/addons:/cri-o:/stable:/v1.31/rpm/repodata/repomd.xml.key
EOF

  log "Repositório CRI-O configurado."
else
  log "Repositório CRI-O já está configurado corretamente."
fi

# Passo 8: Instalar dependências de pacotes, se necessário
log "Verificando se o pacote 'container-selinux' está instalado"

if ! rpm -q container-selinux > /dev/null 2>&1; then
  log "Instalando o pacote 'container-selinux'."
  sudo dnf install -y container-selinux
  log "Pacote 'container-selinux' instalado."
else
  log "Pacote 'container-selinux' já está instalado."
fi

# Passo 9: Configurar o repositório ZFS, se necessário
log "Verificando a configuração do repositório ZFS"

zfs_repo_file="/etc/yum.repos.d/zfs.repo"
zfs_expected_baseurl="https://nexus.seu_dominio.com.br/repository/zfsonlinux"

if [ ! -f "$zfs_repo_file" ] || ! grep -q "$zfs_expected_baseurl" "$zfs_repo_file"; then
  log "Configurando o repositório ZFS."
  
  sudo tee "$zfs_repo_file" > /dev/null << 'EOF'
[zfs-kmod]
# original repo http://download.zfsonlinux.org/epel/
name=ZFS on Linux for EL$releasever - kmod
baseurl=https://nexus.seu_dominio.com.br/repository/zfsonlinux/$releasever/kmod/$basearch/
enabled=1
metadata_expire=7d
gpgcheck=0
EOF

  log "Repositório ZFS configurado."
else
  log "Repositório ZFS já está configurado corretamente."
fi

# Instalar o pacote ZFS, se necessário
if ! rpm -q zfs > /dev/null 2>&1; then
  log "Instalando o pacote ZFS."
  sudo dnf install -y zfs
  log "Pacote ZFS instalado."
else
  log "Pacote ZFS já está instalado."
fi

# Configurar o carregamento automático dos módulos br_netfilter e zfs
log "Configurando o carregamento automático dos módulos br_netfilter e zfs"

# Configurar o carregamento automático do módulo br_netfilter
if [ ! -f /etc/modules-load.d/br_netfilter.conf ]; then
  echo "br_netfilter" | sudo tee /etc/modules-load.d/br_netfilter.conf
  log "Módulo br_netfilter configurado para carregamento automático."
else
  log "Módulo br_netfilter já está configurado para carregamento automático."
fi

# Configurar o carregamento automático do módulo zfs
if [ ! -f /etc/modules-load.d/zfs.conf ]; then
  echo "zfs" | sudo tee /etc/modules-load.d/zfs.conf
  log "Módulo zfs configurado para carregamento automático."
else
  log "Módulo zfs já está configurado para carregamento automático."
fi

# Passo 10: Criar o pool ZFS 'crio-pool' no disco /dev/sda usando caminho persistente
log "Criando o pool ZFS 'crio-pool' no disco /dev/sda"

persistent_path=$(readlink -f /dev/sda)

if [ -z "$persistent_path" ]; then
  log "Erro ao identificar o caminho persistente para /dev/sda."
  exit 1
fi

if sudo zpool list | grep -q "crio-pool"; then
  log "O pool ZFS 'crio-pool' já existe."
else
  sudo zpool create crio-pool "$persistent_path"
  log "Pool ZFS 'crio-pool' criado com sucesso."
fi

# Passo 11: Instalar o CRI-O
log "Verificando se o CRI-O já está instalado."

if rpm -q cri-o > /dev/null 2>&1; then
  log "CRI-O já está instalado, pulando a instalação."
else
  log "Instalando o CRI-O e configurando para usar o pool ZFS"
  dnf install -y cri-o
  check_command "Instalar CRI-O"
  systemctl enable crio
  check_command "Habilitar CRI-O"

  # Caminho do arquivo de configuração
  file_path="/etc/crio/crio.conf.d/10-crio.conf"

  # Conteúdo a ser adicionado
  config_content="[storage]
driver = \"overlay\"
runroot = \"/crio-pool/run/containers/storage\"
graphroot = \"/crio-pool/lib/containers/storage\""

  # Verificar se a configuração já existe no arquivo
  if grep -q "driver = \"overlay\"" "$file_path"; then
    log "Configuração já existe no arquivo $file_path"
  else
    echo "$config_content" | tee -a "$file_path"
    check_command "Adicionar configuração ao arquivo $file_path"
    log "Configuração adicionada ao arquivo $file_path"
  fi

  log "Configuração do CRI-O concluída. Reiniciando o CRI-O."
  systemctl daemon-reload
  check_command "Recarregar daemon do systemd"
  systemctl restart crio
  check_command "Reiniciar CRI-O"
  log "Serviço CRI-O reiniciado."
fi

# Passo 12: Instalar kubelet, kubeadm e kubectl
log "Instalando kubelet, kubeadm, e kubectl"

if ! rpm -q kubelet kubeadm kubectl > /dev/null 2>&1; then
  sudo dnf install -y kubelet kubeadm kubectl --disableexcludes=kubernetes
  log "Pacotes kubelet, kubeadm e kubectl instalados."
else
  log "Pacotes kubelet, kubeadm e kubectl já estão instalados."
fi

# Habilitar e iniciar o serviço kubelet
log "Habilitando e iniciando o serviço kubelet"
sudo systemctl enable --now kubelet

# Passo 13: Criar e carregar o script de configuração do proxy do CRI-O no sistema

if [ ! -f /etc/profile.d/crio-proxy.sh ] || ! grep -q "ativar_proxy_crio" /etc/profile.d/crio-proxy.sh; then
  sudo tee /etc/profile.d/crio-proxy.sh > /dev/null << 'EOF'
# Função para ativar o proxy no CRI-O
function ativar_proxy_crio() {
  sudo mkdir -p /etc/systemd/system/crio.service.d
  
  sudo tee /etc/systemd/system/crio.service.d/proxy.conf > /dev/null << 'EOL'
[Service]
Environment="HTTP_PROXY=http://proxy.seu_dominio.intranet:3128"
Environment="HTTPS_PROXY=http://proxy.seu_dominio.intranet:3128"
Environment="NO_PROXY=localhost,127.0.0.1"
EOL

  sudo systemctl daemon-reload
  sudo systemctl restart crio
  echo "Proxy ativado no CRI-O"
}

# Função para desativar o proxy no CRI-O
function desativar_proxy_crio() {
  if [ -f /etc/systemd/system/crio.service.d/proxy.conf ]; then
    sudo rm /etc/systemd/system/crio.service.d/proxy.conf
    echo "Arquivo de proxy removido"
  fi

  sudo systemctl daemon-reload
  sudo systemctl restart crio
  echo "Proxy desativado no CRI-O"
}
EOF

  sudo chmod +x /etc/profile.d/crio-proxy.sh
  echo "Arquivo /etc/profile.d/crio-proxy.sh criado e configurado."
else
  echo "Arquivo /etc/profile.d/crio-proxy.sh já existe e está configurado."
fi

# Verificar se as funções estão carregadas no ambiente
if ! declare -f ativar_proxy_crio > /dev/null; then
  echo "Carregando o script /etc/profile.d/crio-proxy.sh no ambiente."
  source /etc/profile.d/crio-proxy.sh
else
  echo "Funções de proxy do CRI-O já estão carregadas no ambiente."
fi
