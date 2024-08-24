# Guia de Configuração do Certificado SSL/TLS
Este guia explica como configurar o certificado SSL/TLS gerado pelo Dolutech Automatic Certificate System (DACS) em servidores web populares, como Apache e Nginx, utilizando a estrutura de diretórios do DACS.

## Estrutura dos Arquivos Gerados
Após emitir o certificado usando o DACS, os seguintes arquivos serão gerados na pasta correspondente ao domínio:

Chave Privada: Dolutech-Automatic-Certificate-System/.dolutech/dacs.sh/.acme.sh/exemplodominio.com/exemplodominio.com.key
Certificado: Dolutech-Automatic-Certificate-System/.dolutech/dacs.sh/.acme.sh/exemplodominio.com/exemplodominio.com.cer
Certificado da Autoridade: Dolutech-Automatic-Certificate-System/.dolutech/dacs.sh/.acme.sh/exemplodominio.com/ca.cer
Cadeia Completa de Certificados: Dolutech-Automatic-Certificate-System/.dolutech/dacs.sh/.acme.sh/exemplodominio.com/fullchain.cer
Configuração no Apache
Localize o Virtual Host: Abra o arquivo de configuração do Virtual Host do seu domínio. Normalmente, esses arquivos estão localizados em /etc/apache2/sites-available/ ou /etc/httpd/conf.d/.

Edite o Virtual Host: Adicione ou modifique as seguintes diretivas dentro do bloco <VirtualHost *:443> para configurar o SSL:

