#!/bin/bash

# Função para registrar logs das ações do script
log() {
  echo "$(date +'%Y-%m-%d %H:%M:%S') - $1"
}

# Função para verificar se o comando foi executado com sucesso
check_command() {
  if [ $? -ne 0 ]; then
    log "Erro ao executar: $1"
    exit 1
  fi
}

# Passo 1: Criar o arquivo de configuração do proxy em /etc/profile.d/
log "Criando o arquivo /etc/profile.d/proxy.sh"

if [ ! -f /etc/profile.d/proxy.sh ] || ! grep -q "proxy-on" /etc/profile.d/proxy.sh; then
   tee /etc/profile.d/proxy.sh > /dev/null << 'EOF'
function urlencode() {
    local encoded=$(python3 -c "import urllib.parse; import sys; print(urllib.parse.quote(sys.argv[1]))" $1)
    echo $encoded
}

function proxy-off() {
    unset proxy http_proxy HTTP_PROXY https_proxy HTTPS_PROXY empresa_proxy
}

function proxy-on() {
    username=$1
    if [ -z $username ]; then
        proxy=http://spobrproxy.serasa.intranet:3128
    else
        echo "Please, input your password."
        read -s password
        encoded_password=$(urlencode $password)
        proxy=http://$username:$encoded_password@spobrproxy.serasa.intranet:3128
    fi
    http_proxy=$proxy
    HTTP_PROXY=$proxy
    https_proxy=$proxy
    HTTPS_PROXY=$proxy
    export proxy http_proxy https_proxy HTTP_PROXY HTTPS_PROXY
}

function no_proxy(){
  no_proxy="dockerhub.datalabserasaexperian.com.br,registry.datalabserasaexperian.com.br,pypi.datalabserasaexperian.com.br,maven.datalabserasaexperian.com.br,packages.datalabserasaexperian.com.br,10.*"
  export no_proxy
}

if [ -z ${no_proxy} ]; then
  no_proxy
fi
EOF
  check_command "Criar /etc/profile.d/proxy.sh"
   chmod +x /etc/profile.d/proxy.sh
  check_command "Configurar permissões para /etc/profile.d/proxy.sh"
  log "Arquivo /etc/profile.d/proxy.sh criado e configurado."
else
  log "Arquivo /etc/profile.d/proxy.sh já existe e está configurado."
fi

if ! env | grep -q "HTTP_PROXY"; then
  log "Carregando o script /etc/profile.d/proxy.sh no ambiente."
  source /etc/profile.d/proxy.sh
  check_command "Carregar /etc/profile.d/proxy.sh"
else
  log "Proxy já configurado no ambiente."
fi

# Passo 2: Desativar o swap, se estiver ativo
if free | awk '/^Swap:/ {exit !$2}'; then
  log "Swap ativo. Desativando swap..."
   swapoff -a
  check_command "Desativar swap"
   sed -i.bak '/swap/d' /etc/fstab
  check_command "Remover swap do /etc/fstab"
  log "Swap desativado e removido do /etc/fstab."
else
  log "Swap já está desativado."
fi

# Passo 3: Habilitar o encaminhamento de pacotes IPv4, se necessário
log "Verificando o encaminhamento de pacotes IPv4"

if ! sysctl net.ipv4.ip_forward | grep -q "1"; then
  log "Habilitando net.ipv4.ip_forward"
   tee /etc/sysctl.d/k8s.conf > /dev/null << 'EOF'
net.ipv4.ip_forward = 1
EOF
  check_command "Configurar net.ipv4.ip_forward"
   sysctl --system
  check_command "Aplicar configuração do sysctl"
  log "Encaminhamento de pacotes IPv4 habilitado."
else
  log "Encaminhamento de pacotes IPv4 já está habilitado."
fi

# Passo 4: Carregar o módulo br_netfilter
log "Verificando se o módulo br_netfilter está carregado"
if ! lsmod | grep -q br_netfilter; then
  log "Carregando o módulo br_netfilter"
   modprobe br_netfilter
  check_command "Carregar módulo br_netfilter"
  echo "br_netfilter" |  tee /etc/modules-load.d/br_netfilter.conf
  check_command "Configurar persistência do módulo br_netfilter"
  log "Módulo br_netfilter carregado e configurado para persistência."
else
  log "Módulo br_netfilter já está carregado."
fi

# Passo 5: Configurar nameservers em /etc/resolv.conf
log "Editando /etc/resolv.conf para configurar nameservers"

if grep -q "^nameserver 127.0.0.1" /etc/resolv.conf; then
  log "Comentando o nameserver 127.0.0.1"
   sed -i.bak 's/^nameserver 127.0.0.1/# &/' /etc/resolv.conf
  check_command "Comentar nameserver 127.0.0.1"
fi

# Adicionar novos nameservers se não estiverem presentes
for ns in 10.96.215.13 10.96.216.4 10.96.216.20; do
  if ! grep -q "nameserver $ns" /etc/resolv.conf; then
    log "Adicionando nameserver $ns"
    echo "nameserver $ns" |  tee -a /etc/resolv.conf
    check_command "Adicionar nameserver $ns"
  fi
done

log "Configuração do /etc/resolv.conf concluída."

# Passo 6: Configurar o repositório Kubernetes, se necessário
log "Verificando a configuração do repositório Kubernetes"

repo_file="/etc/yum.repos.d/kubernetes.repo"
expected_baseurl="https://pkgs.k8s.io/core:/stable:/v1.31/rpm/"

if [ ! -f "$repo_file" ] || ! grep -q "$expected_baseurl" "$repo_file"; then
  log "Configurando o repositório Kubernetes."
   tee "$repo_file" > /dev/null << 'EOF'
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.31/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.31/rpm/repodata/repomd.xml.key
exclude=kubelet kubeadm kubectl cri-tools kubernetes-cni
EOF
  check_command "Configurar repositório Kubernetes"
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
   tee "$cri_o_repo_file" > /dev/null << EOF
[cri-o]
name=CRI-O
baseurl=https://pkgs.k8s.io/addons:/cri-o:/stable:/v1.31/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/addons:/cri-o:/stable:/v1.31/rpm/repodata/repomd.xml.key
EOF
  check_command "Configurar repositório CRI-O"
  log "Repositório CRI-O configurado."
else
  log "Repositório CRI-O já está configurado corretamente."
fi

# Passo 8: Instalar dependências de pacotes, se necessário
log "Verificando se o pacote 'container-selinux' está instalado"

if ! rpm -q container-selinux > /dev/null 2>&1; then
  log "Instalando o pacote 'container-selinux'."
   dnf install -y container-selinux
  check_command "Instalar container-selinux"
  log "Pacote 'container-selinux' instalado."
else
  log "Pacote 'container-selinux' já está instalado."
fi

# Passo 9: Configurar o repositório ZFS, se necessário
log "Verificando a configuração do repositório ZFS"

zfs_repo_file="/etc/yum.repos.d/zfs.repo"
zfs_expected_baseurl="https://nexus.datalabserasaexperian.com.br/repository/zfsonlinux"

if [ ! -f "$zfs_repo_file" ] || ! grep -q "$zfs_expected_baseurl" "$zfs_repo_file"; then
  log "Configurando o repositório ZFS."
   tee "$zfs_repo_file" > /dev/null << 'EOF'
[zfs-kmod]
# original repo http://download.zfsonlinux.org/epel/
name=ZFS on Linux for EL$releasever - kmod
baseurl=https://nexus.datalabserasaexperian.com.br/repository/zfsonlinux/$releasever/kmod/$basearch/
enabled=1
metadata_expire=7d
gpgcheck=0
EOF
  check_command "Configurar repositório ZFS"
  log "Repositório ZFS configurado."
else
  log "Repositório ZFS já está configurado corretamente."
fi

# Instalar o pacote ZFS, se necessário
if ! rpm -q zfs > /dev/null 2>&1; then
  log "Instalando o pacote ZFS."
   dnf install -y zfs
  check_command "Instalar ZFS"
  log "Pacote ZFS instalado."
else
  log "Pacote ZFS já está instalado."
fi

# Configurar o carregamento automático dos módulos br_netfilter e zfs
log "Configurando o carregamento automático dos módulos br_netfilter e zfs"

# Configurar o carregamento automático do módulo br_netfilter
if [ ! -f /etc/modules-load.d/br_netfilter.conf ]; then
  echo "br_netfilter" |  tee /etc/modules-load.d/br_netfilter.conf
  check_command "Configurar carregamento automático do módulo br_netfilter"
  log "Módulo br_netfilter configurado para carregamento automático."
else
  log "Módulo br_netfilter já está configurado para carregamento automático."
fi

# Configurar o carregamento automático do módulo zfs
if [ ! -f /etc/modules-load.d/zfs.conf ]; then
  echo "zfs" |  tee /etc/modules-load.d/zfs.conf
  check_command "Configurar carregamento automático do módulo zfs"
  log "Módulo zfs configurado para carregamento automático."
else
  log "Módulo zfs já está configurado para carregamento automático."
fi

# Verificar e carregar os módulos ZFS
if ! lsmod | grep -q zfs; then
  log "Carregando os módulos ZFS."
  sudo /sbin/modprobe zfs
  check_command "Carregar módulos ZFS"
  log "Módulos ZFS carregados com sucesso."
else
  log "Módulos ZFS já estão carregados."
fi

# # Passo 10: Criar o pool ZFS 'crio-pool' no disco /dev/sda usando caminho persistente
# log "Criando o pool ZFS 'crio-pool' no disco /dev/sda"

# persistent_path=$(readlink -f /dev/sda)
# check_command "Identificar caminho persistente para /dev/sda"

# if [ -z "$persistent_path" ]; then
#   log "Erro ao identificar o caminho persistente para /dev/sda."
#   exit 1
# fi

# if  zpool list | grep -q "crio-pool"; then
#   log "O pool ZFS 'crio-pool' já existe."
# else
#    zpool create crio-pool "$persistent_path"
#   check_command "Criar pool ZFS 'crio-pool'"
#   log "Pool ZFS 'crio-pool' criado com sucesso."
# fi

# Passo 11: Instalar o CRI-O
log "Verificando se o CRI-O já está instalado."

if rpm -q cri-o > /dev/null 2>&1; then
  log "CRI-O já está instalado, pulando a instalação."
else
  log "Instalando o CRI-O"
  dnf install -y cri-o
  check_command "Instalar CRI-O"
  systemctl enable crio
  check_command "Habilitar CRI-O"
  log "Instalação do CRI-O concluída."
fi

# Passo 12: Instalar crictl
log "Instalando crictl"

VERSION="v1.31.1"  # Definir a versão correta do crictl

if ! command -v crictl &> /dev/null; then
  # Baixar e instalar a nova versão
  wget https://github.com/kubernetes-sigs/cri-tools/releases/download/$VERSION/crictl-$VERSION-linux-amd64.tar.gz
  sudo tar zxvf crictl-$VERSION-linux-amd64.tar.gz -C /usr/local/bin
  rm -f crictl-$VERSION-linux-amd64.tar.gz
  log "crictl instalado com sucesso."

  # Criar arquivo de configuração crictl.yaml
  sudo tee /etc/crictl.yaml > /dev/null << 'EOF'
runtime-endpoint: unix:///var/run/crio/crio.sock
image-endpoint: unix:///var/run/crio/crio.sock
timeout: 10
debug: false
EOF
  log "Configuração crictl.yaml criada."
else
  log "crictl já está instalado."
fi

# Passo 13: Instalar kubelet, kubeadm e kubectl
log "Instalando kubelet, kubeadm, e kubectl"

if ! rpm -q kubelet kubeadm kubectl > /dev/null 2>&1; then
   dnf install -y kubelet kubeadm kubectl --disableexcludes=kubernetes
  check_command "Instalar kubelet, kubeadm e kubectl"
  log "Pacotes kubelet, kubeadm e kubectl instalados."
else
  log "Pacotes kubelet, kubeadm e kubectl já estão instalados."
fi

# Habilitar e iniciar o serviço kubelet
log "Habilitando e iniciando o serviço kubelet"
 systemctl enable --now kubelet
check_command "Habilitar e iniciar kubelet"

# Passo 14: Verificar e garantir que os serviços essenciais estão habilitados para iniciar no boot

log "Verificando se os serviços kubelet e cri-o estão habilitados para iniciar automaticamente."

# Função para verificar e habilitar o serviço no boot
verificar_e_habilitar_servico() {
  local servico=$1
  if systemctl is-enabled $servico > /dev/null 2>&1; then
    log "O serviço $servico já está habilitado para iniciar no boot."
  else
    log "Habilitando o serviço $servico para iniciar no boot."
    sudo systemctl enable $servico
    check_command "Habilitar $servico"
  fi
}

# Verificar e habilitar os serviços kubelet e cri-o
verificar_e_habilitar_servico kubelet
verificar_e_habilitar_servico crio

# Verificar o status dos serviços importantes após o reboot
log "Verificando o status dos serviços kubelet e cri-o."

verificar_status_servico() {
  local servico=$1
  if systemctl is-active $servico > /dev/null 2>&1; then
    log "O serviço $servico está em execução."
  else
    log "O serviço $servico não está em execução. Tentando iniciar o serviço $servico."
    sudo systemctl start $servico
    if systemctl is-active $servico > /dev/null 2>&1; then
      log "O serviço $servico foi iniciado com sucesso."
    else
      log "Falha ao iniciar o serviço $servico. Verifique os logs para mais detalhes."
    fi
  fi
}

# Verificar o status dos serviços kubelet e cri-o
verificar_status_servico kubelet
verificar_status_servico crio

log "Configuração concluída."

# Passo 15: Criar e carregar o script de configuração do proxy do CRI-O no sistema

if [ ! -f /etc/profile.d/crio-proxy.sh ] || ! grep -q "ativar_proxy_crio" /etc/profile.d/crio-proxy.sh; then
  sudo tee /etc/profile.d/crio-proxy.sh > /dev/null << 'EOF'
# Função para ativar o proxy no CRI-O
function ativar_proxy_crio() {
  sudo mkdir -p /etc/systemd/system/crio.service.d
  
  sudo tee /etc/systemd/system/crio.service.d/proxy.conf > /dev/null << 'EOL'
[Service]
Environment="HTTP_PROXY=http://spobrproxy.serasa.intranet:3128"
Environment="HTTPS_PROXY=http://spobrproxy.serasa.intranet:3128"
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
