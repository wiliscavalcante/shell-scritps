```markdown
# Scripts OpenVPN

Este diretório contém scripts específicos para o gerenciamento do OpenVPN. O foco
principal é automatizar a manutenção e a renovação de certificados SSL/TLS
utilizados pelo OpenVPN.

## renew_openvpn_cert.sh

### Descrição
O script `renew_openvpn_cert.sh` automatiza o processo de renovação dos certificados
SSL/TLS emitidos pelo Let's Encrypt para uso no servidor OpenVPN. Após a renovação,
o script também atualiza a configuração do OpenVPN com os novos certificados e
reinicia o serviço para aplicar as mudanças.

### Pré-requisitos
- `certbot` instalado e configurado no servidor.
- Acesso root ou permissões sudo para executar os comandos necessários.
- OpenVPN Access Server instalado e em funcionamento.

### Como usar

1. Coloque o script `renew_openvpn_cert.sh` no diretório `/root` do servidor.
2. Dê permissão de execução ao script:
   ```bash
   chmod +x /root/renew_openvpn_cert.sh
   ```
3. Configure o `cron` para executar o script automaticamente a cada 60 dias,
   garantindo que o certificado seja renovado antes da expiração:
   ```bash
   crontab -e
   ```
   Adicione a seguinte linha:
   ```bash
   0 0 */60 * * /root/renew_openvpn_cert.sh >> /var/log/renew_cert.log 2>&1
   ```

### Funcionalidades
- Renova automaticamente o certificado Let's Encrypt usando o Certbot.
- Atualiza as chaves e certificados do OpenVPN Access Server.
- Reinicia o serviço OpenVPN para garantir que as novas configurações sejam aplicadas.

### Logs e Monitoramento
Os logs da execução do script serão armazenados em `/var/log/renew_cert.log`. É
recomendável monitorar esses logs para garantir que a renovação do certificado e a
reinicialização do OpenVPN ocorram sem problemas.

### Considerações Finais
Este script foi projetado para simplificar a renovação de certificados e a manutenção
do OpenVPN, minimizando o tempo de inatividade e garantindo a segurança contínua das
conexões VPN.
```
