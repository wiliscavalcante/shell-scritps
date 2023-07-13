#!/bin/bash

# Configuração dos dispositivos e pontos de montagem
DEVICES=("/dev/nvme1n1" "/dev/nvme1n2")
MOUNT_POINTS=("/data" "/backup")

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
