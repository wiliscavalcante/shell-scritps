#!/bin/bash

# Lê a variável de ambiente contendo a chave SSH privada
CHAVE_SSH_PRIVADA=$(echo "$SSH_PRIVATE_KEY")

# Remove as linhas BEGIN e END
CHAVE_SSH_PRIVADA=$(echo "$CHAVE_SSH_PRIVADA" | sed '/^-----BEGIN OPENSSH PRIVATE KEY-----$/d' | sed '/^-----END OPENSSH PRIVATE KEY-----$/d')

# Substitui espaços por quebras de linha
CHAVE_SSH_PRIVADA=$(echo "$CHAVE_SSH_PRIVADA" | tr ' ' '\n')

# Escreve a chave em um arquivo temporário
echo "$CHAVE_SSH_PRIVADA" > /tmp/id_rsa

# Define as permissões corretas
chmod 600 /tmp/id_rsa

# Use /tmp/id_rsa para suas operações de SSH
# Exemplo: clonar um repositório Git
GIT_SSH_COMMAND='ssh -i /tmp/id_rsa -o StrictHostKeyChecking=no' git clone git@github.com:usuario/repositorio.git

# Limpeza: remove o arquivo temporário após o uso
rm /tmp/id_rsa
