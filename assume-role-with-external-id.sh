#!/bin/bash

# Autor: Wilis Cavalcante
# Data: 30/04/2024
# Descrição: Este script assume uma role na AWS utilizando o AWS CLI e configura um perfil temporário com as credenciais obtidas.
# O script é útil para operações que requerem permissões elevadas temporariamente.

# Configurações iniciais
ROLE_ARN="arn:aws:iam::ACCOUNT_ID:role/ROLE_NAME"  # Substitua ACCOUNT_ID e ROLE_NAME pelos valores reais.
ROLE_SESSION_NAME="TemporarySession"
TEMP_PROFILE_NAME="tempProfile"
EXTERNAL_ID="Your-External-ID"  # Substitua com o seu External ID real.

# Assume a role usando AWS Security Token Service (STS) e guarda as credenciais temporárias em um arquivo
aws sts assume-role --role-arn $ROLE_ARN --role-session-name $ROLE_SESSION_NAME --external-id $EXTERNAL_ID > temp_creds.json

# Extrai as credenciais temporárias do arquivo JSON usando 'grep' e 'awk'
ACCESS_KEY=$(grep AccessKeyId temp_creds.json | awk -F'"' '{print $4}')
SECRET_ACCESS_KEY=$(grep SecretAccessKey temp_creds.json | awk -F'"' '{print $4}')
SESSION_TOKEN=$(grep SessionToken temp_creds.json | awk -F'"' '{print $4}')
EXPIRATION=$(grep Expiration temp_creds.json | awk -F'"' '{print $4}')

# Remove o arquivo temporário para evitar armazenamento de credenciais sensíveis no disco
rm temp_creds.json

# Cria ou atualiza o perfil temporário no arquivo de configuração da AWS CLI com as novas credenciais
aws configure set aws_access_key_id $ACCESS_KEY --profile $TEMP_PROFILE_NAME
aws configure set aws_secret_access_key $SECRET_ACCESS_KEY --profile $TEMP_PROFILE_NAME
aws configure set aws_session_token $SESSION_TOKEN --profile $TEMP_PROFILE_NAME

# Informa ao usuário que as credenciais foram configuradas e mostra a data de expiração
echo "Credenciais temporárias configuradas para o perfil $TEMP_PROFILE_NAME até $EXPIRATION"

