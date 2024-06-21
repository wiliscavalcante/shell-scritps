import json
import boto3
import os
import logging

# Configurar o logger
logger = logging.getLogger()
logger.setLevel(logging.WARNING)  # Alterar nível de log para WARNING

s3 = boto3.client('s3')

def object_exists(bucket, key, size):
    try:
        head_response = s3.head_object(Bucket=bucket, Key=key)
        return head_response['ContentLength'] == size
    except s3.exceptions.ClientError as e:
        if e.response['Error']['Code'] == "404":
            return False
        else:
            raise

def lambda_handler(event, context):
    source_bucket = os.environ['SOURCE_BUCKET']
    destination_bucket = os.environ['DESTINATION_BUCKET']
    
    # Obter todos os prefixos das variáveis de ambiente
    prefix_keys = [key for key in os.environ.keys() if key.startswith('PREFIX')]
    prefixes = [os.environ[key] for key in prefix_keys]

    total_files_copied = 0
    total_size_copied = 0
    total_files_skipped = 0
    total_errors = 0

    for prefix in prefixes:
        logger.info(f"Processing prefix: {prefix}")
        paginator = s3.get_paginator('list_objects_v2')
        for page in paginator.paginate(Bucket=source_bucket, Prefix=prefix):
            if 'Contents' not in page:
                continue
            for obj in page['Contents']:
                copy_source = {'Bucket': source_bucket, 'Key': obj['Key']}
                destination_key = obj['Key']
                
                # Verificar se o objeto já existe no bucket de destino
                if object_exists(destination_bucket, destination_key, obj['Size']):
                    total_files_skipped += 1
                    continue
                
                # Get the metadata of the object
                try:
                    head_response = s3.head_object(Bucket=source_bucket, Key=obj['Key'])
                except Exception as e:
                    logger.warning(f"Failed to get metadata for {obj['Key']}: {e}")
                    total_errors += 1
                    continue

                metadata = head_response['Metadata']
                content_type = head_response.get('ContentType')
                
                try:
                    s3.copy_object(
                        CopySource=copy_source,
                        Bucket=destination_bucket,
                        Key=destination_key,
                        Metadata=metadata,
                        MetadataDirective='REPLACE',
                        ContentType=content_type
                    )
                    total_files_copied += 1
                    total_size_copied += obj['Size']
                except Exception as e:
                    logger.warning(f"Failed to copy {obj['Key']} to {destination_key}: {e}")
                    total_errors += 1

    logger.warning(f"Total files copied: {total_files_copied}")
    logger.warning(f"Total size copied: {total_size_copied / (1024 ** 3):.2f} GB")
    logger.warning(f"Total files skipped: {total_files_skipped}")
    logger.warning(f"Total errors: {total_errors}")

    return {
        'statusCode': 200,
        'body': json.dumps('Sincronização completa')
    }
