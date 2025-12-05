# Dolutech Automatic Certificate System (DACS)

![Dolutech Logo](https://dolutech.com/wp-content/uploads/2023/02/dolutech-new-logo.png)

## Versão 2.0.0 🚀

O **Dolutech Automatic Certificate System (DACS)** é uma solução automatizada moderna e completa para emissão, renovação e gerenciamento de certificados SSL/TLS usando ACME. Compatível com múltiplas Certificate Authorities incluindo Let's Encrypt, ZeroSSL, Buypass e Google Trust Services.

## ✨ Novidades da Versão 2.0.0

### Melhorias de Interface
- **Interface colorida e moderna** com ícones e melhor organização visual
- **Menu reorganizado** em categorias lógicas (Certificados, Automação, Backup/Deploy, Sistema)
- **Mensagens de status claras** com indicadores visuais (✓, ✗, ⚠, ℹ)
- **Modo CLI não-interativo** para automação e scripts

### Novas Funcionalidades

#### Gerenciamento Avançado de Certificados
- **Suporte a wildcard** (*.example.com)
- **Múltiplos domínios** em um único certificado (SAN)
- **Validação DNS (DNS-01)** além do webroot (HTTP-01)
- **Modo standalone** para servidores sem webroot
- **Listagem detalhada** com status de expiração e alertas
- **Validação robusta** de domínios e emails

#### Múltiplas Certificate Authorities
- Let's Encrypt (Produção e Staging)
- ZeroSSL
- Buypass (Produção e Teste)
- Google Trust Services (Produção e Staging)

#### Suporte a DNS Providers
- Cloudflare
- AWS Route53
- DigitalOcean
- GoDaddy
- Namecheap
- E muitos outros via acme.sh

#### Sistema de Backup
- **Backup automático** ao emitir ou renovar certificados
- **Rotação de backups** (mantém os 5 mais recentes)
- **Listagem de backups** por domínio
- **Backup manual** sob demanda

#### Deploy Automático
- **Nginx** com configuração SSL/TLS otimizada
- **Apache** com exemplo de VirtualHost
- **Deploy personalizado** com comandos customizados
- **Reload automático** dos servidores web

#### Sistema de Logs Melhorado
- **Logs separados** (principal e erros)
- **Rotação automática** (limite de 10MB)
- **Níveis de log** (INFO, ERROR, WARNING)
- **Busca nos logs** integrada
- **Visualização paginada** com less

#### Segurança e Confiabilidade
- **Validação de entrada** robusta
- **Tratamento de erros** aprimorado
- **Modo seguro** com `set -euo pipefail`
- **Confirmações** para operações destrutivas

## 📋 Requisitos

- **Sistema Operacional**: Linux/Unix/macOS
- **Dependências**:
  - `bash` 4.0+
  - `curl`
  - `openssl`
  - `crontab`
  - `tput` (opcional, para cores)
  - `tar` e `gzip` (para backups)

## 🚀 Instalação

### 1. Clone o Repositório

```bash
git clone https://github.com/dolutech/Dolutech-Automatic-Certificate-System.git
cd Dolutech-Automatic-Certificate-System
```

### 2. Torne o Script Executável

```bash
chmod +x dacs.sh
```

### 3. Execute o Script

#### Modo Interativo
```bash
./dacs.sh
```

#### Modo CLI (Não-Interativo)
```bash
./dacs.sh help
```

## 📖 Utilização

### Modo Interativo

Ao executar `./dacs.sh` sem argumentos, você verá um menu interativo organizado:

```
╔════════════════════════════════════════════╗
║   Dolutech Automatic Certificate System   ║
║            Versao: 2.0.0                   ║
╚════════════════════════════════════════════╝

GERENCIAMENTO DE CERTIFICADOS
  1. Emitir Certificado
  2. Listar Certificados
  3. Renovar Certificado
  4. Remover Certificado

AUTOMACAO
  5. Ativar Renovacao Automatica
  6. Ver Renovacoes Automaticas

BACKUP E DEPLOY
  7. Fazer Backup de Certificado
  8. Listar Backups
  9. Deploy de Certificado

SISTEMA
  10. Ver Logs
  11. Limpar Logs
  0. Sair
```

### Modo CLI (Linha de Comando)

O DACS 2.0 agora suporta execução não-interativa para automação:

#### Comandos Disponíveis

```bash
# Mostrar ajuda
./dacs.sh help

# Mostrar versão
./dacs.sh version

# Emitir certificado
./dacs.sh issue -d example.com -c letsencrypt -w /var/www/html

# Emitir com DNS (requer variáveis de ambiente configuradas)
./dacs.sh issue -d example.com --dns cloudflare

# Emitir wildcard
./dacs.sh issue -d "*.example.com" --dns cloudflare

# Emitir em modo standalone
./dacs.sh issue -d example.com --standalone

# Renovar certificado
./dacs.sh renew -d example.com

# Remover certificado
./dacs.sh remove -d example.com

# Listar certificados
./dacs.sh list
```

#### Opções do Comando Issue

- `-d, --domain DOMAIN` - Domínio do certificado (obrigatório)
- `-c, --ca CA` - Certificate Authority (padrão: letsencrypt)
  - Opções: letsencrypt, zerossl, buypass, google
- `-w, --webroot PATH` - Caminho do webroot para HTTP-01 (padrão: /var/www/html)
- `--dns PROVIDER` - Provider DNS para DNS-01 challenge
- `--standalone` - Usar modo standalone

## 🎯 Exemplos de Uso

### Emitir Certificado com Let's Encrypt (HTTP-01)

```bash
./dacs.sh issue -d example.com -c letsencrypt -w /var/www/html
```

### Emitir Certificado Wildcard com DNS

```bash
# Configure as variáveis de ambiente primeiro
export CF_Key="sua-api-key"
export CF_Email="seu@email.com"

./dacs.sh issue -d "*.example.com" --dns cloudflare
```

### Emitir com Múltiplos Domínios (Modo Interativo)

1. Execute `./dacs.sh` e escolha opção 1
2. Selecione a CA desejada
3. Escolha o método de validação
4. Digite o domínio principal
5. Quando perguntado, adicione domínios extras (SAN)

### Configurar Renovação Automática

```bash
# Via CLI
./dacs.sh enable-auto -d example.com

# Ou modo interativo (opção 5 no menu)
```

### Fazer Backup Manual

```bash
# Modo interativo (opção 7)
./dacs.sh
# Escolha opção 7 e selecione o domínio
```

### Deploy para Nginx

1. Execute `./dacs.sh` e escolha opção 9
2. Selecione o certificado
3. Escolha opção 1 (Nginx)
4. Copie a configuração exibida para seu arquivo de configuração
5. Opcionalmente, recarregue o Nginx automaticamente

## 📁 Estrutura de Diretórios

```
$HOME/.dolutech/dacs.sh/
├── certs/                    # Certificados organizados por domínio
│   └── example.com/
│       ├── example.com.cer   # Certificado
│       ├── example.com.key   # Chave privada
│       ├── fullchain.cer     # Cadeia completa
│       ├── ca.cer            # Certificado CA
│       └── metadata.txt      # Informações do certificado
├── backups/                  # Backups automáticos
│   └── example.com/
│       ├── backup_20231201_120000.tar.gz
│       └── backup_20231215_120000.tar.gz
├── config/
│   └── dacs.conf            # Arquivo de configuração
├── .acme.sh/                # Diretório do acme.sh
├── dacs.log                 # Log principal
├── dacs.error.log           # Log de erros
└── dacs_cron.log            # Registro de renovações automáticas
```

## ⚙️ Configuração

O arquivo de configuração está localizado em `~/.dolutech/dacs.sh/config/dacs.conf`:

```bash
# Certificate Authority padrão
DEFAULT_CA="letsencrypt"

# Método de validação padrão
DEFAULT_CHALLENGE="webroot"

# Caminho webroot padrão
DEFAULT_WEBROOT="/var/www/html"

# Backup automático ao emitir/renovar
AUTO_BACKUP="true"

# Email para notificações (futuro)
NOTIFICATION_EMAIL=""
```

## 🔒 Segurança

### Boas Práticas

1. **Proteção de chaves privadas**: Todos os certificados e chaves são armazenados com permissões apropriadas
2. **Validação de entrada**: Domínios e emails são validados antes do processamento
3. **Backups automáticos**: Certificados são automaticamente salvos antes de operações destrutivas
4. **Logs de auditoria**: Todas as operações são registradas com timestamp

### Permissões Recomendadas

```bash
chmod 700 ~/.dolutech/dacs.sh
chmod 600 ~/.dolutech/dacs.sh/certs/*/example.com.key
```

## 🔄 Renovação Automática

O DACS configura renovações automáticas via cron. Por padrão:

- **Frequência**: A cada 60 dias
- **Método**: Via crontab do usuário
- **Logs**: Salvos em `dacs.log`
- **Backup**: Automático após renovação bem-sucedida

Para verificar renovações agendadas:
```bash
crontab -l | grep dacs
```

## 📊 Status de Certificados

O comando de listagem (opção 2 ou `./dacs.sh list`) mostra:

- ✅ **Status: Válido** - Certificado válido com mais de 30 dias
- ⚠️ **Status: Expira em breve** - Menos de 30 dias até expiração
- ❌ **Status: EXPIRADO** - Certificado já expirou
- Dias restantes até expiração
- Data de emissão

## 🛠️ Troubleshooting

### Problema: "acme.sh não pode ser instalado"

**Solução**: Verifique sua conexão com internet e tente novamente. O script instalará automaticamente.

### Problema: "Falha ao emitir certificado"

**Soluções**:
1. Verifique se o domínio está apontando para o servidor
2. Para webroot, confirme que o caminho está correto e acessível
3. Para DNS, verifique se as credenciais estão corretas
4. Consulte os logs: `./dacs.sh` → Opção 10

### Problema: DNS Challenge não funciona

**Solução**: Configure as variáveis de ambiente do seu provider:

```bash
# Cloudflare
export CF_Key="your-api-key"
export CF_Email="your@email.com"

# Route53
export AWS_ACCESS_KEY_ID="your-key-id"
export AWS_SECRET_ACCESS_KEY="your-secret"

# DigitalOcean
export DO_API_KEY="your-api-key"
```

### Problema: Cores não aparecem

**Solução**: Instale `tput` ou use um terminal que suporte cores ANSI.

## 🔄 Atualizando do DACS 1.x para 2.0

A versão 2.0 é compatível com certificados existentes. Simplesmente:

1. Faça backup dos certificados existentes
2. Substitua o script antigo pelo novo
3. Execute `./dacs.sh` - o ambiente será atualizado automaticamente

## 🤝 Contribuição

Contribuições são bem-vindas! Para contribuir:

1. Fork o repositório
2. Crie uma branch para sua feature (`git checkout -b feature/MinhaFeature`)
3. Commit suas mudanças (`git commit -m 'Adiciona MinhaFeature'`)
4. Push para a branch (`git push origin feature/MinhaFeature`)
5. Abra um Pull Request

## 📝 Changelog

### Versão 2.0.0 (2024)

#### Adicionado
- Interface colorida com melhor UX
- Modo CLI não-interativo completo
- Suporte a múltiplas CAs (ZeroSSL, Buypass, Google)
- Validação DNS (DNS-01) com múltiplos providers
- Suporte a certificados wildcard
- Suporte a múltiplos domínios (SAN)
- Sistema de backup automático
- Deploy automático para Nginx/Apache
- Listagem detalhada com status de expiração
- Sistema de logs melhorado com rotação
- Validação robusta de entrada
- Arquivo de configuração

#### Melhorado
- Menu reorganizado em categorias
- Tratamento de erros aprimorado
- Documentação expandida
- Segurança com modo bash strict
- Organização de código modular

#### Corrigido
- Problemas com certificados ECC
- Rotação de logs
- Gerenciamento de cron
- Compatibilidade com diferentes sistemas

### Versão 1.0.0 (2023)

- Lançamento inicial
- Suporte básico para Let's Encrypt e ZeroSSL
- Interface interativa simples
- Renovação manual e automática

## 📄 Licença

Este projeto está licenciado sob a Licença GPL v3 - veja o arquivo [LICENSE.md](LICENSE.md) para detalhes.

## 👤 Autor

**Lucas Catão de Moraes**

- Website: [https://cataodemoraes.com](https://cataodemoraes.com)
- Empresa: [Dolutech](https://dolutech.com)
- GitHub: [@dolutech](https://github.com/dolutech)

## 🙏 Agradecimentos

- [acme.sh](https://github.com/acmesh-official/acme.sh) - A base deste sistema
- Let's Encrypt - Por tornar SSL/TLS acessível a todos
- Comunidade open source

## 📞 Suporte

Para suporte, visite:
- Website: [https://dolutech.com](https://dolutech.com)
- Issues: [GitHub Issues](https://github.com/dolutech/Dolutech-Automatic-Certificate-System/issues)
- Email: Disponível no website

---

**Feito com ❤️ pela [Dolutech](https://dolutech.com)**

*Simplificando a segurança web, um certificado por vez.*
