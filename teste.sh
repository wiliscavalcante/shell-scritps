#!/bin/bash
echo "$(date) - Launch template startup script started!"

# configure access to the outside internet through the proxy
export http_proxy="http://usaeast-proxy.us.experian.eeca:9595"
export https_proxy="http://usaeast-proxy.us.experian.eeca:9595"
export no_proxy=".experian.eeca,localhost,127.0.0.1,169.254.169.254,api,testserver,internal-brain-lb-platform-dev-1449535370.sa-east-1.elb.amazonaws.com"
export PIP_INDEX_URL="https://nexus.agribusiness-brain.br.experian.eeca/repository/pypi-hub/simple"
export PIP_TRUSTED_HOST="nexus.agribusiness-brain.br.experian.eeca"
 
# Importando Certificado do Nexus
echo "$(date) - Downloading cert.pem ..."
aws s3 cp s3://agribusiness-ec2-certs/cert_nexus.pem /tmp/cert.pem

# Atualiza os pacotes do sistema
echo "$(date) - updating system packages ..."
sudo yum update -y

# Instalação do Git
echo "$(date) - installing GIT ..."
sudo yum install git -y

# Instalação do Docker
echo "$(date) - Installing docker ..."
sudo yum install docker -y
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -a -G docker ec2-user

# Instalação do docker-compose
echo "$(date) - Installing docker-compose ..."
python3.11 -m pip install --upgrade pip
python3.11 -m pip install docker==6.1.3 requests==2.31.0 PyYAML==5.3.1 docker-compose==1.29.2


# install AWS EFS setup lib
echo "$(date) - Installing amazon-efs-utils ..."
sudo yum install -y amazon-efs-utils.noarch

# Faz backup do conteúdo da home do usuário ec2-user para /tmp
echo "$(date) - Backup of the /home folder ..."
sudo tar -czf "/tmp/ec2-user_backup.tar.gz" -C /home .

# Configuração dos dispositivos e pontos de montagem
DEVICES=("/dev/nvme1n1")
MOUNT_POINTS=("/home")

# Loop para formatar e montar os dispositivos
for ((i=0; i<${#DEVICES[@]}; i++)); do
    DEVICE=${DEVICES[$i]}
    MOUNT_POINT=${MOUNT_POINTS[$i]}

    # Verifica se o dispositivo já está formatado como XFS
    if ! sudo xfs_info "$DEVICE" >/dev/null 2>&1; then
        sudo mkfs.xfs "$DEVICE"
    fi

    # Cria o diretório de ponto de montagem, se não existir
    if [ ! -d "$MOUNT_POINT" ]; then
        sudo mkdir "$MOUNT_POINT"
    fi

    # Monta o dispositivo no ponto de montagem
    sudo mount "$DEVICE" "$MOUNT_POINT"

    # Obtém o UUID do dispositivo
    UUID=$(sudo blkid -s UUID -o value "$DEVICE")

    # Adiciona uma entrada no /etc/fstab para montagem automática
    if ! sudo grep -q "$UUID" /etc/fstab; then
        echo "UUID=$UUID $MOUNT_POINT xfs defaults,nofail 0 2" | sudo tee -a /etc/fstab
    fi
done

# Comenta a linha do fstab referente a montagem padrao do /home
# para que depois do reboot ele nao tente montar a home assim, e sim do jeito definido acima
sudo sed -i '/^\/dev\/mapper\/rootvg-home/s//#&/' /etc/fstab

# Restaura o conteúdo do backup na nova home do usuário ec2-user
sudo tar -xzf "/tmp/ec2-user_backup.tar.gz" -C /home

# Remove o arquivo de backup
sudo rm "/tmp/ec2-user_backup.tar.gz"

# Configura variaveis de ambiente
conteudo_arquivo=$(cat <<EOF
#!/bin/bash

export http_proxy=${http_proxy};
export https_proxy=${https_proxy};
export no_proxy=${no_proxy};
export PIP_INDEX_URL=${PIP_INDEX_URL};
export PIP_TRUSTED_HOST=${PIP_TRUSTED_HOST};

EOF
)
echo "$conteudo_arquivo" | sudo tee /etc/profile.d/variaveis.sh > /dev/null
sudo chmod +x /etc/profile.d/variaveis.sh

# Configura montagem  do EFS no filesystem da instancia:
# pega o efs id a ser montado
export KEYNAME=$(ec2-metadata --public-keys | grep keyname | sed 's/[^:]*//' | cut -c 2-)
declare -A keyname_to_efs_id=( \
    ["pedro-pimenta"]="fs-0916fec4bb939d013" \
    ["zeni"]="fs-04828e4d73c735edf" \
    ["luis-macedo-virginia"]="fs-0a2b653604b1b3ad3" \
    ["mateus-silva"]="fs-0d0a7a86c67fc3a93" \
    ["alex-araujo-sbx-virginia"]="fs-01ba7578331a69bf8" \
    ["lucimara-bragagnolo"]="fs-00b79b5936842f735" \
    ["mislene-nunes"]="fs-0d0a7a86c67fc3a93" \
    ["kenia_santos"]="fs-0d0a7a86c67fc3a93" \
    ["mbalboni"]="fs-0d0a7a86c67fc3a93" \
    ["gabriel-ferreira-virginia"]="fs-031d26424db7c73e3" \
    ["allan-lima"]="fs-0e178674a147e0161" \
    ["nicksson-virginia"]="fs-0f57e8edf7f5beba4" \
    ["cleverton-santana"]="fs-0e27965f52b06a725" \
    ["alves-aws-key"]="fs-03d9493157dd84689" \
    ["alvaro_virginia"]="fs-0e0effe7f5ca1dd89" \
)
export EFS_ID=${keyname_to_efs_id[${KEYNAME}]}
# cria ponto de montagem do EFS
sudo mkdir /home/ec2-user/efs
# registra informacao de montagem (qual volume, onde montar, configuracoes)
sudo echo "$EFS_ID:/ /home/ec2-user/efs efs _netdev,noresvport,tls,iam 0 0" | sudo tee -a /etc/fstab

# Move a pasta do Docker para dentro de /home para não
# consumir espaço do disco onde a root está montada
sudo service docker stop
sudo mv /var/lib/docker /home/docker
sudo ln -s /home/docker /var/lib/docker
sudo service docker start

# Define a permissão correta para o usuário ec2-user no ponto de montagem
sudo chown -R ec2-user:ec2-user /home/ec2-user

# Monta volumes descritos em /etc/fstab
echo "$(date) - Mounting volumes (including EFS)..."
sudo mount -a

# Ajusta o dono do EFS montado para ser acessivel pelo ec2-user
sudo chown -R ec2-user:ec2-user /home/ec2-user/efs

# cria arquivo de configuração do proxy HTTP e HTTPS
echo "$(date) - Setting up proxy env vars for docker ..."
sudo mkdir -p /etc/systemd/system/docker.service.d/
echo -e "[Service]\nEnvironment=\"HTTP_PROXY=${http_proxy}\"\nEnvironment=\"HTTPS_PROXY=${https_proxy}\"\nEnvironment=\"NO_PROXY=${no_proxy}\"\nEnvironment=\"PIP_INDEX_URL=${PIP_INDEX_URL}\"\nEnvironment=\"PIP_TRUSTED_HOST=${PIP_TRUSTED_HOST}\"" | sudo tee /etc/systemd/system/docker.service.d/http-proxy.conf > /dev/null

sudo -u ec2-user mkdir -p /home/ec2-user/.docker
decoded_content=$(echo "ewogICAgInByb3hpZXMiOiB7CiAgICAgICAgImRlZmF1bHQiOiB7CiAgICAgICAgICAgICJodHRwUHJveHkiOiAiaHR0cDovL3VzYWVhc3QtcHJveHkudXMuZXhwZXJpYW4uZWVjYTo5NTk1IiwKICAgICAgICAgICAgImh0dHBzUHJveHkiOiAiaHR0cDovL3VzYWVhc3QtcHJveHkudXMuZXhwZXJpYW4uZWVjYTo5NTk1IgogICAgICAgIH0KICAgIH0KfQ==" | base64 -d)
echo "$decoded_content" | sudo tee /home/ec2-user/.docker/config.json > /dev/null
sudo chown ec2-user:ec2-user /home/ec2-user/.docker/config.json

# Docker Insecure Registries
echo "$(date) - Setting up Docker Insecure Registries ..."
decoded_insecure_registry=$(echo "ewoiaW5zZWN1cmUtcmVnaXN0cmllcyI6IFsiZG9ja2VyaHViLmFncmlidXNpbmVzcy1icmFpbi5ici5leHBlcmlhbi5lZWNhIiwicmVnaXN0cnkuYWdyaWJ1c2luZXNzLWJyYWluLmJyLmV4cGVyaWFuLmVlY2EiLCJyZWdpc3RyeS1zbmFwc2hvdC5hZ3JpYnVzaW5lc3MtYnJhaW4uYnIuZXhwZXJpYW4uZWVjYSJdCn0=" | base64 -d)
echo "$decoded_insecure_registry" | sudo tee /etc/docker/daemon.json > /dev/null


echo "$(date) - Reloading daemon and restarting docker ..."
sudo systemctl daemon-reload
sudo systemctl restart docker

# Cria esse arquivo na home pro usuário saber que a máquina está pronta
sudo touch /home/ec2-user/maquina_pronta.txt
echo "$(date) - Done!"
