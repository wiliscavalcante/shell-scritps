#!/bin/bash

# Script para listar e deletar volumes EBS disponíveis e não utilizados na AWS.
# O script:
# 1. Lista todos os volumes disponíveis (sem uso) na conta AWS.
# 2. Pede confirmação do usuário antes de deletar os volumes.
# 3. Exclui os volumes disponíveis, mostrando o status de sucesso ou falha.

# Função para listar volumes disponíveis
list_available_volumes() {
    aws ec2 describe-volumes --query "Volumes[?State=='available'].VolumeId" --output text
}

# Função para deletar volumes disponíveis
delete_volumes() {
    local volumes=$1
    for volume_id in $volumes; do
        aws ec2 delete-volume --volume-id $volume_id
        if [ $? -eq 0 ]; then
            echo "Deleted volume: $volume_id"
        else
            echo "Failed to delete volume: $volume_id"
        fi
    done
}

# Listar volumes disponíveis
available_volumes=$(list_available_volumes)

# Verificar se há volumes disponíveis
if [ -z "$available_volumes" ]; then
    echo "Nenhum volume disponível para deletar."
    exit 0
fi

# Mostrar os volumes disponíveis e pedir confirmação
echo "Volumes disponíveis para deletar:"
for volume_id in $available_volumes; do
    echo $volume_id
done

read -p "Você realmente deseja deletar esses volumes? (y/n): " confirm

if [[ $confirm == "y" || $confirm == "Y" ]]; then
    delete_volumes "$available_volumes"
else
    echo "Operação cancelada pelo usuário."
fi
