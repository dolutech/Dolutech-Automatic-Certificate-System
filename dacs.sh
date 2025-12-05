#!/usr/bin/env sh

# ===========================================================
# Dolutech Automatic Certificate System (DACS)
# Criado por Lucas Catao de Moraes
# Website: https://dolutech.com
# Versao: 1.0.0 - Baseado no Acme.sh
# ===========================================================
# Logs: arquivo principal em $LOG_FILE e logs por operacao em $LOG_DIR/<operacao>_<dominio>_<timestamp>.log

# Configuracao do Ambiente
VERSION="1.0.0"
PROJECT_NAME="dacs.sh"
DEFAULT_INSTALL_HOME="$HOME/.dolutech/$PROJECT_NAME"
CERT_DIR="$DEFAULT_INSTALL_HOME/certs"
ACME_SH="$DEFAULT_INSTALL_HOME/acme.sh"
ACME_HOME="$DEFAULT_INSTALL_HOME/.acme.sh"
LOG_DIR="$DEFAULT_INSTALL_HOME/logs"
LOG_FILE="$DEFAULT_INSTALL_HOME/dacs.log"
CRON_FILE="$DEFAULT_INSTALL_HOME/dacs_cron.log"
MAX_LOG_SIZE=$((1024 * 1024)) # 1MB por arquivo
MAX_LOG_BACKUPS=5
CA_ZEROSSL="https://acme.zerossl.com/v2/DV90"
CA_LETSENCRYPT="https://acme-v02.api.letsencrypt.org/directory"
RELOAD_CMD="${RELOAD_CMD:-systemctl reload nginx}"
ACME_DOWNLOAD_URL="https://get.acme.sh"

# Rotacao simples de logs
rotate_log_file() {
    FILE="$1"
    [ ! -f "$FILE" ] && return

    FILE_SIZE=$(wc -c < "$FILE")
    if [ "$FILE_SIZE" -lt "$MAX_LOG_SIZE" ]; then
        return
    fi

    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    ROTATED_FILE="${FILE}.${TIMESTAMP}"
    mv "$FILE" "$ROTATED_FILE"
    touch "$FILE"

    BACKUPS=$(ls -1t "${FILE}."* 2>/dev/null | tail -n +$((MAX_LOG_BACKUPS + 1)))
    if [ -n "$BACKUPS" ]; then
        echo "$BACKUPS" | xargs rm -f --
    fi
}

# Funcao para logar as acoes
log_action() {
    rotate_log_file "$LOG_FILE"
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# Cria arquivo de log especifico por operacao
create_operation_log() {
    OPERATION="$1"
    DOMAIN="$2"
    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    LOG_PATH="$LOG_DIR/${OPERATION}_${DOMAIN}_${TIMESTAMP}.log"
    echo "Operacao: $OPERATION" > "$LOG_PATH"
    echo "Dominio: $DOMAIN" >> "$LOG_PATH"
    echo "Horario: $(date +'%Y-%m-%d %H:%M:%S')" >> "$LOG_PATH"
    echo "----------------------------------------" >> "$LOG_PATH"
    echo "$LOG_PATH"
}

# Instalacao do acme.sh se nao estiver presente
install_acme_sh() {
    if [ -f "$ACME_SH" ]; then
        return
    fi

    if ! command -v curl >/dev/null 2>&1; then
        echo "A ferramenta 'curl' e necessaria para instalar o acme.sh."
        exit 1
    fi

    echo "Instalando acme.sh com verificacao basica..."
    read -p "Informe o e-mail para registrar no acme.sh (pressione Enter para usar um e-mail generico): " ACME_EMAIL
    [ -z "$ACME_EMAIL" ] && ACME_EMAIL="admin@example.com"

    mkdir -p "$ACME_HOME"
    TEMP_INSTALLER=$(mktemp)

    if ! curl -fL "$ACME_DOWNLOAD_URL" -o "$TEMP_INSTALLER"; then
        echo "Falha ao baixar o instalador do acme.sh."
        exit 1
    fi

    DOWNLOAD_CHECKSUM=$(sha256sum "$TEMP_INSTALLER" | awk '{print $1}')
    log_action "acme.sh baixado. SHA256=${DOWNLOAD_CHECKSUM}"

    if sh "$TEMP_INSTALLER" --home "$ACME_HOME" --accountemail "$ACME_EMAIL"; then
        mv "$ACME_HOME/acme.sh" "$ACME_SH"
        chmod +x "$ACME_SH"
        log_action "acme.sh instalado com sucesso usando email $ACME_EMAIL."
    else
        log_action "Falha ao instalar acme.sh com email $ACME_EMAIL."
        echo "Erro ao instalar acme.sh. Verifique os logs."
        exit 1
    fi

    rm -f "$TEMP_INSTALLER"
}

# Inicializa o ambiente
init_env() {
    mkdir -p "$DEFAULT_INSTALL_HOME"
    mkdir -p "$CERT_DIR"
    mkdir -p "$LOG_DIR"
    touch "$LOG_FILE"
    touch "$CRON_FILE"
    install_acme_sh
    echo "Ambiente inicializado para $PROJECT_NAME versao $VERSION"
}

# Permite escolher metodo de validacao
select_validation_method() {
    echo "Escolha o metodo de validacao:"
    echo "1. Webroot (customizavel)"
    echo "2. Standalone"
    echo "3. DNS (fornecedor configurado no acme.sh)"
    read -p "Opcao (1/2/3): " VALIDATION_OPTION

    case "$VALIDATION_OPTION" in
        1)
            read -p "Informe o caminho do webroot [/var/www/html]: " WEBROOT_PATH
            [ -z "$WEBROOT_PATH" ] && WEBROOT_PATH="/var/www/html"
            if [ ! -d "$WEBROOT_PATH" ]; then
                echo "Webroot informado nao existe: $WEBROOT_PATH"
                return 1
            fi
            VALIDATION_ARGS="--webroot $WEBROOT_PATH"
            VALIDATION_DESC="webroot:$WEBROOT_PATH"
            ;;
        2)
            VALIDATION_ARGS="--standalone"
            VALIDATION_DESC="standalone"
            ;;
        3)
            read -p "Informe o provedor DNS configurado (ex: dns_cf): " DNS_PROVIDER
            if [ -z "$DNS_PROVIDER" ]; then
                echo "Fornecedor DNS nao informado."
                return 1
            fi
            VALIDATION_ARGS="--dns $DNS_PROVIDER"
            VALIDATION_DESC="dns:$DNS_PROVIDER"
            ;;
        *)
            echo "Opcao invalida."
            return 1
            ;;
    esac

}

# Executa comando com log dedicado
run_acme_command() {
    COMMAND="$1"
    LOG_PATH="$2"
    sh -c "$COMMAND" >> "$LOG_PATH" 2>&1
}

# Funcao para emitir certificado com Let's Encrypt
issue_certificate_letsencrypt() {
    read -p "Insira o dominio para o certificado (exemplo: exemplo.com) ou digite 'v' para voltar: " DOMAIN
    [ "$DOMAIN" = "v" ] && return
    if ! select_validation_method; then
        read -p "Pressione v para voltar ao menu..." response
        return
    fi

    OP_LOG=$(create_operation_log "issue_letsencrypt" "$DOMAIN")
    COMMAND="$ACME_SH --issue --server $CA_LETSENCRYPT -d $DOMAIN $VALIDATION_ARGS --home $ACME_HOME"

    if run_acme_command "$COMMAND" "$OP_LOG"; then
        organize_certificates "$DOMAIN"
        show_certificate_paths "$DOMAIN"
        log_action "Certificado emitido com sucesso para $DOMAIN usando $VALIDATION_DESC. Log: $OP_LOG"
        echo "Certificado emitido com sucesso!"
    else
        log_action "Erro ao emitir certificado para $DOMAIN usando $VALIDATION_DESC. Verifique $OP_LOG"
        echo "Erro ao emitir certificado para $DOMAIN."
    fi
    read -p "Pressione v para voltar ao menu..." response
}

# Funcao para emitir certificado com ZeroSSL
issue_certificate_zerossl() {
    read -p "Insira o dominio para o certificado (exemplo: exemplo.com) ou digite 'v' para voltar: " DOMAIN
    [ "$DOMAIN" = "v" ] && return
    if ! select_validation_method; then
        read -p "Pressione v para voltar ao menu..." response
        return
    fi

    OP_LOG=$(create_operation_log "issue_zerossl" "$DOMAIN")
    COMMAND="$ACME_SH --issue --server $CA_ZEROSSL -d $DOMAIN $VALIDATION_ARGS --home $ACME_HOME"

    if run_acme_command "$COMMAND" "$OP_LOG"; then
        organize_certificates "$DOMAIN"
        show_certificate_paths "$DOMAIN"
        log_action "Certificado emitido com sucesso para $DOMAIN usando $VALIDATION_DESC. Log: $OP_LOG"
        echo "Certificado emitido com sucesso!"
    else
        log_action "Erro ao emitir certificado para $DOMAIN usando $VALIDATION_DESC. Verifique $OP_LOG"
        echo "Erro ao emitir certificado para $DOMAIN."
    fi
    read -p "Pressione v para voltar ao menu..." response
}

# Organiza os certificados criando atalhos ao invs de mover
organize_certificates() {
    DOMAIN="$1"
    DOMAIN_CERT_DIR="$CERT_DIR/$DOMAIN"
    mkdir -p "$DOMAIN_CERT_DIR"

    # Criar atalhos dos arquivos de certificados
    ln -sf "$ACME_HOME/${DOMAIN}_ecc/${DOMAIN}.key" "$DOMAIN_CERT_DIR/"
    ln -sf "$ACME_HOME/${DOMAIN}_ecc/${DOMAIN}.cer" "$DOMAIN_CERT_DIR/"
    ln -sf "$ACME_HOME/${DOMAIN}_ecc/fullchain.cer" "$DOMAIN_CERT_DIR/"
    ln -sf "$ACME_HOME/${DOMAIN}_ecc/ca.cer" "$DOMAIN_CERT_DIR/"

    echo "Atalhos dos certificados criados em $DOMAIN_CERT_DIR"
    log_action "Certificado emitido para $DOMAIN e atalhos criados em $DOMAIN_CERT_DIR"
}

# Mostra os caminhos dos certificados emitidos
show_certificate_paths() {
    DOMAIN="$1"
    DOMAIN_CERT_DIR="$CERT_DIR/$DOMAIN"
    echo "============================================"
    echo "Certificado emitido com sucesso!"
    echo "Caminho do certificado: $DOMAIN_CERT_DIR/$DOMAIN.cer"
    echo "Caminho da chave privada: $DOMAIN_CERT_DIR/$DOMAIN.key"
    echo "Caminho do certificado CA: $DOMAIN_CERT_DIR/ca.cer"
    echo "Caminho da cadeia completa: $DOMAIN_CERT_DIR/fullchain.cer"
    echo "============================================"
}

# Renovacao de certificado
renew_certificate() {
    CERTIFICATES=$(ls -1 "$CERT_DIR" 2>/dev/null)
    if [ -z "$CERTIFICATES" ]; then
        echo "Nenhum certificado encontrado para renovacao."
        return
    fi

    echo "============================================"
    echo "Certificados disponiveis para renovacao:"
    echo "============================================"
    CERT_LIST=$(echo "$CERTIFICATES")
    for i in $(seq 1 $(echo "$CERT_LIST" | wc -l)); do
        echo "$i. $(echo "$CERT_LIST" | sed -n "${i}p")"
    done
    echo "============================================"
    read -p "Escolha o numero do dominio para renovar ou digite 'v' para voltar: " DOMAIN_NUM
    [ "$DOMAIN_NUM" = "v" ] && return
    DOMAIN=$(echo "$CERT_LIST" | sed -n "${DOMAIN_NUM}p")

    if [ -d "$CERT_DIR/$DOMAIN" ]; then
        OP_LOG=$(create_operation_log "renew" "$DOMAIN")
        COMMAND="$ACME_SH --renew -d $DOMAIN --home $ACME_HOME"
        if run_acme_command "$COMMAND" "$OP_LOG"; then
            organize_certificates "$DOMAIN"
            show_certificate_paths "$DOMAIN"
            log_action "Certificado para $DOMAIN renovado com sucesso. Log: $OP_LOG"
            echo "Certificado para $DOMAIN renovado com sucesso!"
        else
            log_action "Erro ao renovar certificado para $DOMAIN. Verifique $OP_LOG"
            echo "Erro ao renovar certificado para $DOMAIN."
        fi
    else
        echo "Dominio nao encontrado."
    fi
    read -p "Pressione v para voltar ao menu..." response
}

# Remover certificado
remove_certificate() {
    CERTIFICATES=$(ls -1 "$CERT_DIR" 2>/dev/null)
    if [ -z "$CERTIFICATES" ]; then
        echo "Nenhum certificado encontrado para remocao."
        return
    fi

    echo "============================================"
    echo "Certificados disponiveis para remocao:"
    echo "============================================"
    CERT_LIST=$(echo "$CERTIFICATES")
    for i in $(seq 1 $(echo "$CERT_LIST" | wc -l)); do
        echo "$i. $(echo "$CERT_LIST" | sed -n "${i}p")"
    done
    echo "============================================"
    read -p "Escolha o numero do dominio para remover ou digite 'v' para voltar: " DOMAIN_NUM
    [ "$DOMAIN_NUM" = "v" ] && return
    DOMAIN=$(echo "$CERT_LIST" | sed -n "${DOMAIN_NUM}p")

    if [ -d "$CERT_DIR/$DOMAIN" ]; then
        OP_LOG=$(create_operation_log "remove" "$DOMAIN")
        {
            rm -rf "$CERT_DIR/$DOMAIN"
            rm -rf "$ACME_HOME/${DOMAIN}_ecc"
        } >> "$OP_LOG" 2>&1
        log_action "Certificado para $DOMAIN removido. Log: $OP_LOG"
        echo "Certificado para $DOMAIN removido com sucesso."
    else
        echo "Dominio nao encontrado."
    fi
    read -p "Pressione v para voltar ao menu..." response
}

# Configurar renovacao automatica via cron a cada 89 dias
enable_auto_renewal() {
    CERTIFICATES=$(ls -1 "$CERT_DIR" 2>/dev/null)
    if [ -z "$CERTIFICATES" ]; then
        echo "Nenhum certificado disponivel para ativar renovacao automatica."
        return
    fi

    echo "Certificados disponiveis para ativar renovacao automatica:"
    CERT_LIST=$(echo "$CERTIFICATES")

    for i in $(seq 1 $(echo "$CERT_LIST" | wc -l)); do
        echo "$i. $(echo "$CERT_LIST" | sed -n "${i}p")"
    done

    read -p "Escolha o numero do dominio para ativar a renovacao automatica ou digite 'v' para voltar: " DOMAIN_NUM
    [ "$DOMAIN_NUM" = "v" ] && return
    DOMAIN=$(echo "$CERT_LIST" | sed -n "${DOMAIN_NUM}p")

    if [ -d "$CERT_DIR/$DOMAIN" ]; then
        CRON_COMMAND="$ACME_SH --renew -d $DOMAIN --home $ACME_HOME --reloadcmd \"$RELOAD_CMD\" >> $LOG_FILE 2>&1"
        CRON_LINE="0 0 */89 * * $CRON_COMMAND"
        (crontab -l 2>/dev/null | grep -v "$ACME_SH --renew -d $DOMAIN"; echo "$CRON_LINE") | crontab -
        echo "Renovacao automatica ativada para $DOMAIN a cada 89 dias."
        log_action "Renovacao automatica ativada para $DOMAIN a cada 89 dias. Reload: $RELOAD_CMD"
        if ! grep -q "^$DOMAIN$" "$CRON_FILE" 2>/dev/null; then
            echo "$DOMAIN" >> "$CRON_FILE"
        fi
    else
        echo "Dominio nao encontrado."
    fi
    read -p "Pressione v para voltar ao menu..." response
}

# Consultar logs
view_logs() {
    if [ -s "$LOG_FILE" ]; then
        echo "Logs do sistema:"
        cat "$LOG_FILE"
    else
        echo "Nenhum log encontrado."
    fi
    read -p "Pressione v para voltar ao menu..." response
}

# Limpar logs
clear_logs() {
    > "$LOG_FILE"
    rm -f "$LOG_DIR"/*.log.* "$LOG_DIR"/*.log
    echo "Logs limpos."
    read -p "Pressione v para voltar ao menu..." response
}

# Visualizar renovacoes automaticas
view_auto_renewals() {
    if [ -s "$CRON_FILE" ]; then
        echo "Renovacoes automaticas ativas:"
        AUTO_RENEWALS=$(cat "$CRON_FILE")
        for i in $(seq 1 $(echo "$AUTO_RENEWALS" | wc -l)); do
            echo "$i. $(echo "$AUTO_RENEWALS" | sed -n "${i}p")"
        done
        read -p "Deseja desativar a renovacao automatica de algum dominio? (s/n): " RESPONSE
        if [ "$RESPONSE" = "s" ] || [ "$RESPONSE" = "S" ]; then
            read -p "Escolha o numero do dominio para desativar a renovacao automatica ou digite 'v' para voltar: " RENEWAL_NUM
            [ "$RENEWAL_NUM" = "v" ] && return
            DOMAIN=$(echo "$AUTO_RENEWALS" | sed -n "${RENEWAL_NUM}p")
            deactivate_auto_renewal "$DOMAIN"
        else
            echo "Operacao cancelada."
        fi
    else
        echo "Nao possui dominios configurados para renovacoes automaticas."
    fi
    read -p "Pressione v para voltar ao menu..." response
}

# Desativar renovacao automatica
deactivate_auto_renewal() {
    DOMAIN="$1"
    crontab -l 2>/dev/null | grep -v "$ACME_SH --renew -d $DOMAIN" | crontab -
    sed -i "/^$DOMAIN$/d" "$CRON_FILE"
    echo "Renovacao automatica desativada para $DOMAIN."
    log_action "Renovacao automatica desativada para $DOMAIN."
    read -p "Pressione v para voltar ao menu..." response
}

# Menu principal
menu() {
    while true; do
        clear
        echo "============================================"
        echo "Dolutech Automatic Certificate System"
        echo "Versao: $VERSION"
        echo "============================================"
        echo "1. Emitir Certificado com Let's Encrypt"
        echo "2. Emitir Certificado com ZeroSSL"
        echo "3. Renovar Certificado"
        echo "4. Remover Certificado"
        echo "5. Ativar Renovacao Automatica"
        echo "6. Ver Renovacoes Automaticas"
        echo "7. Consultar Logs"
        echo "8. Limpar Logs"
        echo "9. Sair"
        echo "============================================"
        read -p "Escolha uma opcao: " OPTION

        case $OPTION in
            1)
                issue_certificate_letsencrypt
                ;;
            2)
                issue_certificate_zerossl
                ;;
            3)
                renew_certificate
                ;;
            4)
                remove_certificate
                ;;
            5)
                enable_auto_renewal
                ;;
            6)
                view_auto_renewals
                ;;
            7)
                view_logs
                ;;
            8)
                clear_logs
                ;;
            9)
                echo "Saindo do Dolutech Automatic Certificate System. Ate mais!"
                echo "Obrigado por usar o Dolutech Automatic Certificate System!"
                echo "Acesse https://dolutech.com e conheca nosso blog de tecnologia e ciberseguranca."
                exit 0
                ;;
            *)
                echo "Opcao invalida."
                read -p "Pressione v para voltar ao menu..." response
                ;;
        esac
    done
}

# Execucao
init_env
menu
