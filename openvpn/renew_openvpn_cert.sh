#!/bin/bash

# Defina o domínio
DOMAIN="vpn.exemplo.com"

# Caminho para o Certbot
CERTBOT_PATH=$(which certbot)

# Renovar o certificado automaticamente usando o standalone webserver
$CERTBOT_PATH certonly --non-interactive --standalone --preferred-challenges http --domain $DOMAIN --renew-by-default

# Verificar se o Certbot renovou o certificado
if [ $? -ne 0 ]; then
    echo "Erro ao renovar o certificado. Verifique o log do Certbot para mais detalhes."
    exit 1
fi

# Caminhos dos arquivos gerados pelo Certbot
PRIVKEY="/etc/letsencrypt/live/$DOMAIN/privkey.pem"
CERT="/etc/letsencrypt/live/$DOMAIN/cert.pem"
CHAIN="/etc/letsencrypt/live/$DOMAIN/chain.pem"

# Atualizar o OpenVPN com os novos certificados
/usr/local/openvpn_as/scripts/sacli --key "cs.priv_key" --value_file "$PRIVKEY" ConfigPut
/usr/local/openvpn_as/scripts/sacli --key "cs.cert" --value_file "$CERT" ConfigPut
/usr/local/openvpn_as/scripts/sacli --key "cs.ca_bundle" --value_file "$CHAIN" ConfigPut

# Reiniciar o serviço OpenVPN para aplicar as mudanças
/usr/local/openvpn_as/scripts/sacli start

# Verificar se o serviço foi reiniciado com sucesso
if [ $? -eq 0 ]; then
    echo "Certificado renovado e OpenVPN reiniciado com sucesso."
else
    echo "Erro ao reiniciar o OpenVPN. Verifique o log para mais detalhes."
    exit 1
fi
