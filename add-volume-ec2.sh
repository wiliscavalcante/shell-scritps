#!/bin/bash

# Atualiza os pacotes do sistema
sudo yum update -y

# Configuração dos dispositivos e pontos de montagem
DEVICES=("/dev/nvme1n1" "/dev/nvme1n2")
MOUNT_POINTS=("/data" "/backup")

# Loop para formatar e montar os dispositivos
for ((i=0; i<${#DEVICES[@]}; i++)); do
  DEVICE=${DEVICES[$i]}
  MOUNT_POINT=${MOUNT_POINTS[$i]}

  # Formata o dispositivo como XFS, se necessário
  if ! sudo file -s "$DEVICE" | grep -q "XFS filesystem"; then
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

  # Define a permissão correta para o usuário ec2-user no ponto de montagem
  sudo chown -R ec2-user:ec2-user "$MOUNT_POINT"
done
