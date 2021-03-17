#!/bin/bash

#####################################################################

#Variaveis 

DATE=`date +%d-%m-%Y`
ENDDATE=`date -d '7 days ago' +"%d-%m-%Y"`
MYSQL_USER=root
MYSQL_PASSWORD=root_password
BKP_PATH_DB=~/mysql_backup
S3_BUCKET_DB=s3://your-bucket/
DATABASES_EXCLUDED="(Database|information_schema|performance_schema|mysql)"
databases=`mysql --user=$MYSQL_USER -p$MYSQL_PASSWORD -e "SHOW DATABASES;" | grep -Ev $DATABASES_EXCLUDED`

echo "$databases"

#Removendo arquivos antigos do S3

for db in $databases; do
        aws s3 rm $S3_BUCKET_DB$db-$ENDDATE.sql.gz
done

#Fazendo o dump 

for db in $databases; do
        mysqldump --routines --triggers --force --opt --user=$MYSQL_USER -p$MYSQL_PASSWORD --databases $db | gzip > "$BKP_PATH_DB/$db-$DATE.sql.gz"
done

#Sincronizando com a AWS

aws s3 sync $BKP_PATH_DB $S3_BUCKET_DB

#Apagando arquivos com mais de 7 dias
cd $BKP_PATH_DB
find -mtime +6 -delete