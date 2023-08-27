# #!/bin/bash

# # Configurações
# ROLE_ARN="arn:aws:iam::ACCOUNT_ID:role/ROLE_NAME" # Substitua ACCOUNT_ID e ROLE_NAME
# ROLE_SESSION_NAME="TemporarySession"
# TEMP_PROFILE_NAME="tempProfile"

# # Assume a role e guarda as credenciais temporárias em uma variável
# ASSUMED_ROLE=$(aws sts assume-role --role-arn $ROLE_ARN --role-session-name $ROLE_SESSION_NAME)

# # Extrai as credenciais temporárias usando 'jq'
# ACCESS_KEY=$(echo $ASSUMED_ROLE | jq -r '.Credentials.AccessKeyId')
# SECRET_ACCESS_KEY=$(echo $ASSUMED_ROLE | jq -r '.Credentials.SecretAccessKey')
# SESSION_TOKEN=$(echo $ASSUMED_ROLE | jq -r '.Credentials.SessionToken')
# EXPIRATION=$(echo $ASSUMED_ROLE | jq -r '.Credentials.Expiration')

# # Cria ou atualiza o perfil temporário no arquivo de configuração da AWS CLI
# aws configure set aws_access_key_id $ACCESS_KEY --profile $TEMP_PROFILE_NAME
# aws configure set aws_secret_access_key $SECRET_ACCESS_KEY --profile $TEMP_PROFILE_NAME
# aws configure set aws_session_token $SESSION_TOKEN --profile $TEMP_PROFILE_NAME

# echo "Credenciais temporárias configuradas para o perfil $TEMP_PROFILE_NAME até $EXPIRATION"

#!/bin/bash

# Configurações
ROLE_ARN="arn:aws:iam::ACCOUNT_ID:role/ROLE_NAME"  # Substitua ACCOUNT_ID e ROLE_NAME
ROLE_SESSION_NAME="TemporarySession"
TEMP_PROFILE_NAME="tempProfile"
EXTERNAL_ID="Your-External-ID"  # Substitua com o seu External ID real

# Assume a role e guarda as credenciais temporárias em um arquivo temporário
aws sts assume-role --role-arn $ROLE_ARN --role-session-name $ROLE_SESSION_NAME --external-id $EXTERNAL_ID > temp_creds.json

# Extrai as credenciais temporárias usando 'grep' e 'awk'
ACCESS_KEY=$(grep AccessKeyId temp_creds.json | awk -F'"' '{print $4}')
SECRET_ACCESS_KEY=$(grep SecretAccessKey temp_creds.json | awk -F'"' '{print $4}')
SESSION_TOKEN=$(grep SessionToken temp_creds.json | awk -F'"' '{print $4}')
EXPIRATION=$(grep Expiration temp_creds.json | awk -F'"' '{print $4}')

# Remove o arquivo temporário
rm temp_creds.json

# Cria ou atualiza o perfil temporário no arquivo de configuração da AWS CLI
aws configure set aws_access_key_id $ACCESS_KEY --profile $TEMP_PROFILE_NAME
aws configure set aws_secret_access_key $SECRET_ACCESS_KEY --profile $TEMP_PROFILE_NAME
aws configure set aws_session_token $SESSION_TOKEN --profile $TEMP_PROFILE_NAME

echo "Credenciais temporárias configuradas para o perfil $TEMP_PROFILE_NAME até $EXPIRATION"
