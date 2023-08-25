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

service: meu-servico
provider:
  name: aws
  runtime: nodejs14.x

functions:
  hello:
    handler: handler.hello

resources:
  Resources:
    HelloLambdaCrossAccountPermission:
      Type: 'AWS::Lambda::Permission'
      Properties:
        Action: 'lambda:InvokeFunction'
        FunctionName:
          'Fn::GetAtt':
            - 'HelloLambdaFunction'  # Nome lógico da função Lambda, baseado no nome da função no serverless.yml
            - 'Arn'
        Principal: 'arn:aws:iam::ID_DA_OUTRA_CONTA:role/NomeDaRole'
        StatementId: 'IDUnicoParaEstaPermissao'

{
	"Version": "2012-10-17",
	"Statement": {
		"Effect": "Allow",
		"Action": "sts:AssumeRole",
		"Resource": "arn:aws:iam::539402869524:role/RoleForCrossAccountDeployServerless"
	}
}


