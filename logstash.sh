#!/bin/bash

# Define o caminho para o arquivo jvm.options do Logstash
JVM_OPTIONS_FILE="/caminho/para/seu/logstash/config/jvm.options"

# Parar o serviço Logstash
echo "Parando o serviço Logstash..."
systemctl stop logstash

# Verifica se o Logstash foi parado
if ! systemctl is-active --quiet logstash; then
    echo "Logstash parado com sucesso."

    # Backup do arquivo jvm.options
    cp $JVM_OPTIONS_FILE $JVM_OPTIONS_FILE.bak

    # Altera a configuração Xms para 512m
    sed -i '/^-Xms/c\-Xms512m' $JVM_OPTIONS_FILE

    # Altera a configuração Xmx para 1.5g
    sed -i '/^-Xmx/c\-Xmx1536m' $JVM_OPTIONS_FILE

    echo "Configurações de memória do Logstash atualizadas em $JVM_OPTIONS_FILE"

    # Iniciar o serviço Logstash
    echo "Iniciando o serviço Logstash..."
    systemctl start logstash

    # Verifica se o Logstash foi iniciado
    if systemctl is-active --quiet logstash; then
        echo "Logstash iniciado com sucesso."
    else
        echo "Falha ao iniciar Logstash."
    fi
else
    echo "Falha ao parar Logstash. Verifique o status do serviço."
fi
