import boto3
from airflow import DAG
from airflow.operators.python_operator import PythonOperator
from datetime import datetime

# Função para copiar o arquivo entre buckets
def copy_s3_file(**kwargs):
    # Caminhos específicos dos arquivos no bucket local e no bucket cross-account
    local_bucket = 'nome-do-bucket-local'
    cross_account_bucket = 'nome-do-bucket-cross-account'
    source_path = 'caminho/origem/do/arquivo/'  # Exemplo: 'folder1/folder2/file.txt'
    destination_path = 'caminho/destino/no/bucket/'  # Exemplo: 'folder3/file.txt'
    file_key = 'file.txt'  # Nome do arquivo

    # Criação do recurso S3
    s3 = boto3.resource('s3')
    
    # Objeto no bucket local
    source_object_key = f'{source_path}{file_key}'
    # Destino no bucket cross-account
    destination_object_key = f'{destination_path}{file_key}'

    print(f"Tentando copiar o arquivo {file_key} de {local_bucket}/{source_object_key} para {cross_account_bucket}/{destination_object_key}")
    
    # Definindo a origem do arquivo
    copy_source = {
        'Bucket': local_bucket,
        'Key': source_object_key
    }

    try:
        print(f"Verificando se o arquivo existe no bucket de origem: {local_bucket}/{source_object_key}")
        s3.meta.client.head_object(Bucket=local_bucket, Key=source_object_key)
        print(f"Arquivo {source_object_key} encontrado no bucket de origem")

        # Tentativa de copiar o arquivo
        print(f"Iniciando a cópia do arquivo para o bucket cross-account {cross_account_bucket}/{destination_object_key}...")
        s3.meta.client.copy(
            copy_source, 
            cross_account_bucket, 
            destination_object_key, 
            ExtraArgs={'RequestPayer': 'requester'}
        )
        print(f"Arquivo {file_key} copiado com sucesso para {cross_account_bucket}/{destination_object_key}")
    
    except s3.meta.client.exceptions.NoSuchKey as e:
        print(f"Erro: Arquivo {source_object_key} não encontrado no bucket de origem {local_bucket}.")
    except Exception as e:
        print(f"Erro ao copiar o arquivo: {str(e)}")

# Definindo o DAG
default_args = {
    'owner': 'airflow',
    'start_date': datetime(2024, 9, 17),
}

dag = DAG('copy_s3_file_dag', default_args=default_args, schedule_interval=None)

# Operador Python para executar a função
copy_task = PythonOperator(
    task_id='copy_s3_file_task',
    python_callable=copy_s3_file,
    dag=dag
)
