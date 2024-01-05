#!/bin/bash

# Lê a variável de ambiente contendo a chave SSH privada
CHAVE_SSH_PRIVADA=$(echo "$SSH_PRIVATE_KEY")

# Substitui um caractere específico por quebras de linha
# Aqui, estou assumindo que o caractere é um espaço. Se for diferente, você precisará ajustar isso.
CHAVE_SSH_PRIVADA_FORMATADA=$(echo "$CHAVE_SSH_PRIVADA" | sed 's/ /\n/g')

# Escreve a chave formatada em um arquivo temporário
echo "$CHAVE_SSH_PRIVADA_FORMATADA" > /tmp/id_rsa

# Define as permissões corretas
chmod 600 /tmp/id_rsa

# Use /tmp/id_rsa para suas operações de SSH
# Exemplo: clonar um repositório Git
GIT_SSH_COMMAND='ssh -i /tmp/id_rsa -o StrictHostKeyChecking=no' git clone git@github.com:usuario/repositorio.git

# Limpeza: remove o arquivo temporário após o uso
rm /tmp/id_rsa
