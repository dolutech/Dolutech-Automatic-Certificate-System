# Dolutech Automatic Certificate System (DACS)

![Dolutech Logo](https://dolutech.com/wp-content/uploads/2023/02/dolutech-new-logo.png) <!-- Substitua pelo URL do logotipo da Dolutech se houver -->

## Versão 1.0.0

O **Dolutech Automatic Certificate System (DACS)** é uma solução automatizada para emissão, renovação e gerenciamento de certificados SSL/TLS usando ACME, compatível com Let's Encrypt e ZeroSSL. Este sistema é baseado no script `acme.sh`, oferecendo uma interface simplificada e intuitiva em português.

## Características Principais

- **Compatibilidade**: Suporte para Let's Encrypt e ZeroSSL.
- **Automação**: Emissão, renovação e remoção automáticas de certificados.
- **Gerenciamento Simplificado**: Menu interativo para gerenciar certificados e configurações.
- **Logs**: Sistema de logs para monitorar ações e eventos.
- **Renovação Automática**: Configuração de renovação automática dos certificados via `cron`.

## Requisitos

- **Sistema Operacional**: Linux/Unix
- **Dependências**: `curl`, `sh`, `crontab`

## Instalação

1. **Clone o Repositório**:
   ```bash
   git clone https://github.com/SeuUsuario/Dolutech-Automatic-Certificate-System.git
