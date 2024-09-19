#!/bin/bash

# Coautores: Wilis Cavalcante
# Script para listar e deletar snapshots EBS não utilizados na AWS.
# O script:
# 1. Lista todos os snapshots pertencentes à sua conta AWS.
# 2. Pede confirmação do usuário antes de deletar os snapshots.
# 3. Exclui os snapshots disponíveis, mostrando o status de sucesso ou falha.

# Função para listar snapshots disponíveis
list_available_snapshots() {
    aws ec2 describe-snapshots --owner self --query "Snapshots[*].SnapshotId" --output text
}

# Função para deletar snapshots disponíveis
delete_snapshots() {
    local snapshots=$1
    for snapshot_id in $snapshots; do
        aws ec2 delete-snapshot --snapshot-id $snapshot_id
        if [ $? -eq 0 ]; then
            echo "Deleted snapshot: $snapshot_id"
        else
            echo "Failed to delete snapshot: $snapshot_id"
        fi
    done
}

# Listar snapshots disponíveis
available_snapshots=$(list_available_snapshots)

# Verificar se há snapshots disponíveis
if [ -z "$available_snapshots" ]; then
    echo "Nenhum snapshot disponível para deletar."
    exit 0
fi

# Mostrar os snapshots disponíveis e pedir confirmação
echo "Snapshots disponíveis para deletar:"
for snapshot_id in $available_snapshots; do
    echo $snapshot_id
done

read -p "Você realmente deseja deletar esses snapshots? (y/n): " confirm

if [[ $confirm == "y" || $confirm == "Y" ]]; then
    delete_snapshots "$available_snapshots"
else
    echo "Operação cancelada pelo usuário."
fi

