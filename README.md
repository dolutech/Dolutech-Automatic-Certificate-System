# Dolutech Automatic Certificate System (DACS)

![Dolutech Logo](https://dolutech.com/wp-content/uploads/2023/02/dolutech-new-logo.png)

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

### 1. Clone o Repositório

Clone o repositório do GitHub para a sua máquina local:

```bash
git clone https://github.com/dolutech/Dolutech-Automatic-Certificate-System.git
```
### 2. Navegue até o Diretório

Entre no diretório do projeto clonado:
```bash
cd Dolutech-Automatic-Certificate-System
```
### 3. Conceda Permissão de Execução

Conceda permissão de execução ao script `dacs.sh`:
```bash
chmod +x dacs.sh
```
### 4. Execute o Script

Agora você pode executar o script para iniciar o DACS:

```bash
./dacs.sh
```
## Utilização

Após iniciar o script, você verá um menu interativo com as seguintes opções:

### Menu Principal

1. **Emitir Certificado com Let's Encrypt**: Solicite a emissão de um certificado SSL/TLS para um domínio especificado usando Let's Encrypt.

2. **Emitir Certificado com ZeroSSL**: Solicite a emissão de um certificado SSL/TLS para um domínio especificado usando ZeroSSL.

3. **Renovar Certificado**: Renove um certificado SSL/TLS já existente.

4. **Remover Certificado**: Remova um certificado SSL/TLS, apagando todos os arquivos associados e as entradas no `crontab`.

5. **Ativar Renovação Automática**: Configure a renovação automática de um certificado, agendando a renovação a cada 89 dias via `cron`.

6. **Ver Renovações Automáticas**: Veja uma lista de renovações automáticas configuradas e, se necessário, desative alguma.

7. **Consultar Logs**: Exiba os logs do sistema para monitorar as atividades de emissão, renovação e remoção de certificados.

8. **Limpar Logs**: Limpe o arquivo de logs.

9. **Sair**: Encerre o script e retorne ao terminal.

### Exemplo de Uso

#### Emitindo um Certificado

1. Selecione a opção 1 ou 2 no menu para emitir um certificado com Let's Encrypt ou ZeroSSL.
2. Insira o domínio desejado, como exemplo.com.
3. Aguarde a conclusão do processo. O certificado será emitido e os caminhos dos arquivos serão exibidos.

#### Configurando Renovação Automática

1. Selecione a opção 5 para ativar a renovação automática.
2. Escolha o certificado para o qual deseja configurar a renovação.
3. A renovação será agendada automaticamente.

## Manutenção

Para garantir que os certificados sejam renovados corretamente, o script configura automaticamente as tarefas no crontab. Recomenda-se verificar os logs periodicamente para garantir que tudo está funcionando conforme o esperado.

## Contribuição

Contribuições são bem-vindas! Sinta-se à vontade para abrir issues ou enviar pull requests no repositório do GitHub.

## Licença

Este projeto está licenciado sob a Licença GPL.

## Autor

**[Lucas Catão de Moraes](https://cataodemoraes.com)**  
[Dolutech](https://dolutech.com)

---

Obrigado por usar o Dolutech Automatic Certificate System! Acesse dolutech.com para saber mais sobre nossas soluções de tecnologia e cibersegurança.


