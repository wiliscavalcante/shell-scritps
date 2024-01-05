#!/bin/bash

# Lê a variável de ambiente contendo a chave SSH privada
CHAVE_SSH_PRIVADA=$(echo "$SSH_PRIVATE_KEY")

# Extrai a linha BEGIN
BEGIN_LINE=$(echo "$CHAVE_SSH_PRIVADA" | grep "BEGIN OPENSSH PRIVATE KEY")

# Extrai a linha END
END_LINE=$(echo "$CHAVE_SSH_PRIVADA" | grep "END OPENSSH PRIVATE KEY")

# Remove as linhas BEGIN e END e substitui espaços por quebras de linha no conteúdo
CHAVE_SSH_PRIVADA_CONTEUDO=$(echo "$CHAVE_SSH_PRIVADA" | sed '/BEGIN OPENSSH PRIVATE KEY/d' | sed '/END OPENSSH PRIVATE KEY/d' | tr ' ' '\n')

# Reconstrói a chave com as linhas BEGIN e END
CHAVE_SSH_PRIVADA_FINAL="$BEGIN_LINE\n$CHAVE_SSH_PRIVADA_CONTEUDO\n$END_LINE"

# Escreve a chave no arquivo temporário
echo -e "$CHAVE_SSH_PRIVADA_FINAL" > /tmp/id_rsa

# Define as permissões corretas
chmod 600 /tmp/id_rsa

# Use /tmp/id_rsa para suas operações de SSH
# Exemplo: clonar um repositório Git
GIT_SSH_COMMAND='ssh -i /tmp/id_rsa -o StrictHostKeyChecking=no' git clone git@github.com:usuario/repositorio.git

# Limpeza: remove o arquivo temporário após o uso
rm /tmp/id_rsa
# Suponha que sua chave esteja em /caminho/para/minha_chave
GIT_SSH_COMMAND='ssh -i /caminho/para/minha_chave -o IdentitiesOnly=yes -o StrictHostKeyChecking=no' git clone git@github.com:usuario/repositorio.git


