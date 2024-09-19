#!/bin/bash

# Coautores: Wilis Cavalcante
# Script para listar e deletar AMIs e seus snapshots associados, preservando itens específicos.
# Este script deve ser usado quando você deseja **preservar algumas AMIs** e deletar todas as outras.
# O script:
# 1. Lista todas as AMIs pertencentes à sua conta AWS.
# 2. Verifica se a AMI está na lista de preservação.
# 3. Desregistra as AMIs que não estão na lista de preservação.
# 4. Deleta os snapshots associados às AMIs desregistradas.
# 5. Exibe o status de sucesso ou falha para cada operação.
# Caso precise queira verificar as AMIs utilizadas pelas EC2 da conta use o comando abaixo:
# aws ec2 describe-instances --query "Reservations[*].Instances[*].ImageId" --output text | sort | uniq

# Lista de AMIs a serem preservadas (adicione os IDs das AMIs que você deseja manter)
PRESERVED_AMIS=("ami-12345678" "ami-87654321")

# Função para listar AMIs disponíveis
list_available_amis() {
    aws ec2 describe-images --owners self --query "Images[*].ImageId" --output text
}

# Função para deletar AMIs e seus snapshots, exceto as AMIs preservadas
delete_amis_and_snapshots() {
    local amis=$1
    for ami_id in $amis; do
        # Verificar se a AMI está na lista de preservação
        if [[ " ${PRESERVED_AMIS[@]} " =~ " ${ami_id} " ]]; then
            echo "Preservando AMI: $ami_id"
            continue
        fi

        # Desregistrar a AMI
        echo "Desregistrando AMI: $ami_id..."
        aws ec2 deregister-image --image-id $ami_id 2>/tmp/delete_ami_error.log
        if [ $? -eq 0 ]; then
            echo "AMI desregistrada: $ami_id"
        else
            echo "Falha ao desregistrar AMI: $ami_id"
            cat /tmp/delete_ami_error.log
            continue
        fi

        # Deletar os snapshots associados à AMI
        echo "Deletando snapshots associados à AMI $ami_id..."
        snapshot_ids=$(aws ec2 describe-images --image-ids $ami_id --query "Images[*].BlockDeviceMappings[*].Ebs.SnapshotId" --output text)
        
        if [ -n "$snapshot_ids" ]; then
            for snapshot_id in $snapshot_ids; do
                echo "Deletando snapshot: $snapshot_id..."
                aws ec2 delete-snapshot --snapshot-id $snapshot_id 2>/tmp/delete_snapshot_error.log
                if [ $? -eq 0 ]; then
                    echo "Snapshot deletado: $snapshot_id"
                else
                    echo "Falha ao deletar snapshot: $snapshot_id"
                    cat /tmp/delete_snapshot_error.log
                fi
            done
        else
            echo "Nenhum snapshot associado à AMI $ami_id."
        fi
    done
}

# Listar AMIs disponíveis
available_amis=$(list_available_amis)

# Verificar se há AMIs disponíveis
if [ -z "$available_amis" ]; then
    echo "Nenhuma AMI disponível para deletar."
    exit 0
fi

# Mostrar as AMIs disponíveis e pedir confirmação
echo "AMIs disponíveis para deletar (exceto preservadas):"
for ami_id in $available_amis; do
    echo $ami_id
done

read -p "Você realmente deseja deletar essas AMIs e seus snapshots? (y/n): " confirm

if [[ $confirm == "y" || $confirm == "Y" ]]; then
    delete_amis_and_snapshots "$available_amis"
else
    echo "Operação cancelada pelo usuário."
fi
