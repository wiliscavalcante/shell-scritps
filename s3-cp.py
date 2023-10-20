import boto3
import os

# Nome do bucket público
PUBLIC_BUCKET_NAME = 'nome-do-bucket-publico'

# Nome do bucket privado
PRIVATE_BUCKET_NAME = 'nome-do-bucket-privado'

# Diretório temporário
TEMP_DIR = 'temp-dir'

# Cria o diretório temporário
if not os.path.exists(TEMP_DIR):
    os.makedirs(TEMP_DIR)

# Cria um cliente S3 anônimo para acessar o bucket público
s3_anonymous = boto3.client('s3', config=boto3.Config(signature_version=botocore.UNSIGNED))

# Cria um cliente S3 com credenciais para acessar o bucket privado
s3_authenticated = boto3.client('s3')

# Lista os objetos no bucket público
objects = s3_anonymous.list_objects(Bucket=PUBLIC_BUCKET_NAME)
if 'Contents' not in objects:
    print("No objects in public bucket")
    exit(1)

# Faz o download dos objetos para o diretório temporário
for obj in objects['Contents']:
    file_name = obj['Key']
    download_path = os.path.join(TEMP_DIR, file_name)
    s3_anonymous.download_file(PUBLIC_BUCKET_NAME, file_name, download_path)

# Faz o upload dos objetos do diretório temporário para o bucket privado
for file_name in os.listdir(TEMP_DIR):
    file_path = os.path.join(TEMP_DIR, file_name)
    s3_authenticated.upload_file(file_path, PRIVATE_BUCKET_NAME, f"upload/{file_name}")

# Remove o diretório temporário e seus arquivos
for file_name in os.listdir(TEMP_DIR):
    file_path = os.path.join(TEMP_DIR, file_name)
    os.remove(file_path)

os.rmdir(TEMP_DIR)

#!/bin/bash

# Configurações
ROLE_ARN="arn:aws:iam::ACCOUNT_ID:role/ROLE_NAME" # Substitua ACCOUNT_ID e ROLE_NAME
ROLE_SESSION_NAME="TemporarySession"
TEMP_PROFILE_NAME="tempProfile"

# Assume a role e guarda as credenciais temporárias em uma variável
ASSUMED_ROLE=$(aws sts assume-role --role-arn $ROLE_ARN --role-session-name $ROLE_SESSION_NAME)

# Extrai as credenciais temporárias usando 'jq'
ACCESS_KEY=$(echo $ASSUMED_ROLE | jq -r '.Credentials.AccessKeyId')
SECRET_ACCESS_KEY=$(echo $ASSUMED_ROLE | jq -r '.Credentials.SecretAccessKey')
SESSION_TOKEN=$(echo $ASSUMED_ROLE | jq -r '.Credentials.SessionToken')
EXPIRATION=$(echo $ASSUMED_ROLE | jq -r '.Credentials.Expiration')

# Cria ou atualiza o perfil temporário no arquivo de configuração da AWS CLI
aws configure set aws_access_key_id $ACCESS_KEY --profile $TEMP_PROFILE_NAME
aws configure set aws_secret_access_key $SECRET_ACCESS_KEY --profile $TEMP_PROFILE_NAME
aws configure set aws_session_token $SESSION_TOKEN --profile $TEMP_PROFILE_NAME

echo "Credenciais temporárias configuradas para o perfil $TEMP_PROFILE_NAME até $EXPIRATION"
###############
FROM apache/airflow:2.6.2
COPY requirements.txt /requirements.txt
RUN pip install --user --upgrade pip --trusted-host pypi.org --trusted-host files.pythonhosted.org
RUN pip install --no-cache-dir --user -r /requirements.txt --trusted-host pypi.org --trusted-host files.pythonhosted.org
USER root
RUN apt-get update && \
    apt-get install --allow-downgrades -y libpq5=13.11-0+deb11u1
RUN apt-get install -y libgdal-dev \
    gdal-bin \
    gcc \
    g++
RUN sudo pip install geopandas --trusted-host pypi.org --trusted-host files.pythonhosted.org
RUN sudo pip install --global-option=build_ext --global-option="-I/usr/include/gdal" GDAL==`gdal-config --version` --trusted-host pypi.org --trusted-host files.pythonhosted.org

###New
FROM apache/airflow:2.6.2

USER root

# Instalação de pacotes do sistema
RUN apt-get update && \
    apt-get install --allow-downgrades -y libpq5=13.11-0+deb11u1 \
    libgdal-dev gdal-bin gcc g++

# Mudar de volta para o usuário não-root (airflow)
USER airflow

# Instalação de pacotes Python
RUN pip install --user --upgrade pip --trusted-host pypi.org --trusted-host files.pythonhosted.org

# Copiar e instalar as dependências Python do seu projeto
COPY requirements.txt /requirements.txt
RUN pip install --no-cache-dir --user -r /requirements.txt --trusted-host pypi.org --trusted-host files.pythonhosted.org

# Instalar geopandas e GDAL
RUN pip install geopandas --trusted-host pypi.org --trusted-host files.pythonhosted.org
RUN pip install --global-option=build_ext --global-option="-I/usr/include/gdal" GDAL==$(gdal-config --version) --trusted-host pypi.org --trusted-host files.pythonhosted.org


