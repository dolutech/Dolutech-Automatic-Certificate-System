# Guia de Configuração do Certificado SSL/TLS
Este guia explica como configurar o certificado SSL/TLS gerado pelo Dolutech Automatic Certificate System (DACS) em servidores web populares, como Apache e Nginx, utilizando a estrutura de diretórios do DACS.

## Estrutura dos Arquivos Gerados
Após emitir o certificado usando o DACS, os seguintes arquivos serão gerados na pasta correspondente ao domínio:

- **Chave Privada:** Dolutech-Automatic-Certificate-System/.dolutech/dacs.sh/.acme.sh/exemplodominio.com/exemplodominio.com.key
- **Certificado:** Dolutech-Automatic-Certificate-System/.dolutech/dacs.sh/.acme.sh/exemplodominio.com/exemplodominio.com.cer
- **Certificado da Autoridade:** Dolutech-Automatic-Certificate-System/.dolutech/dacs.sh/.acme.sh/exemplodominio.com/ca.cer
- **Cadeia Completa de Certificados:** Dolutech-Automatic-Certificate-System/.dolutech/dacs.sh/.acme.sh/exemplodominio.com/fullchain.cer

## Configuração no Apache

Localize o Virtual Host: Abra o arquivo de configuração do Virtual Host do seu domínio. Normalmente, esses arquivos estão localizados em /etc/apache2/sites-available/ ou /etc/httpd/conf.d/.
Edite o Virtual Host: Adicione ou modifique as seguintes diretivas dentro do bloco <VirtualHost *:443> para configurar o SSL:

```bash
<VirtualHost *:443>
    ServerName exemplodominio.com
    DocumentRoot /var/www/html

    SSLEngine on
    SSLCertificateFile /caminho/para/Dolutech-Automatic-Certificate-System/.dolutech/dacs.sh/.acme.sh/exemplodominio.com/fullchain.cer
    SSLCertificateKeyFile /caminho/para/Dolutech-Automatic-Certificate-System/.dolutech/dacs.sh/.acme.sh/exemplodominio.com/exemplodominio.com.key
    SSLCertificateChainFile /caminho/para/Dolutech-Automatic-Certificate-System/.dolutech/dacs.sh/.acme.sh/exemplodominio.com/ca.cer

    # Outras configurações...
</VirtualHost>
```
- **SSLCertificateFile:** O caminho para o arquivo fullchain.cer.
- **SSLCertificateKeyFile:** O caminho para o arquivo exemplodominio.com.key.
- **SSLCertificateChainFile:** O caminho para o arquivo ca.cer.

## Habilitar o Módulo SSL: Se ainda não estiver habilitado, execute o comando para habilitar o módulo SSL:

```bash
sudo a2enmod ssl
```

## Reinicie o Apache: Após fazer as alterações, reinicie o Apache para aplicar as configurações:

```bash
sudo systemctl restart apache2
```
## Configuração no Nginx
- **Localize o Bloco de Servidor:** Abra o arquivo de configuração do Nginx para o seu domínio. Normalmente, esses arquivos estão localizados em /etc/nginx/sites-available/ ou /etc/nginx/conf.d/.
- **Edite o Bloco de Servidor:** Adicione ou modifique as seguintes diretivas dentro do bloco server para configurar o SSL:

```bash
server {
    listen 443 ssl;
    server_name exemplodominio.com;

    ssl_certificate /caminho/para/Dolutech-Automatic-Certificate-System/.dolutech/dacs.sh/.acme.sh/exemplodominio.com/fullchain.cer;
    ssl_certificate_key /caminho/para/Dolutech-Automatic-Certificate-System/.dolutech/dacs.sh/.acme.sh/exemplodominio.com/exemplodominio.com.key;
    ssl_trusted_certificate /caminho/para/Dolutech-Automatic-Certificate-System/.dolutech/dacs.sh/.acme.sh/exemplodominio.com/ca.cer;

    root /var/www/html;

    # Outras configurações...
}
```
- **ssl_certificate:** O caminho para o arquivo fullchain.cer.
- **ssl_certificate_key:** O caminho para o arquivo exemplodominio.com.key.
- **ssl_trusted_certificate:** O caminho para o arquivo ca.cer.
- **Teste a Configuração:** Antes de reiniciar o Nginx, teste a configuração para garantir que não há erros:
