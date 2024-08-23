#!/usr/bin/env sh

# ===========================================================
# Dolutech Automatic Certificate System (DACS)
# Criado por Lucas Catao de Moraes
# Website: https://dolutech.com
# Versao: 1.0.0 - Baseado no Acme.sh
# ===========================================================

# Configuracao do Ambiente
VERSION="1.0.0"
PROJECT_NAME="dacs.sh"
DEFAULT_INSTALL_HOME="$HOME/.dolutech/$PROJECT_NAME"
CERT_DIR="$DEFAULT_INSTALL_HOME/certs"
ACME_SH="$DEFAULT_INSTALL_HOME/acme.sh"
ACME_HOME="$DEFAULT_INSTALL_HOME/.acme.sh"
LOG_FILE="$DEFAULT_INSTALL_HOME/dacs.log"
CRON_FILE="$DEFAULT_INSTALL_HOME/dacs_cron.log"
CA_ZEROSSL="https://acme.zerossl.com/v2/DV90"
CA_LETSENCRYPT="https://acme-v02.api.letsencrypt.org/directory"

# Instalacao do acme.sh se nao estiver presente
install_acme_sh() {
    if [ ! -f "$ACME_SH" ]; then
        echo "Instalando acme.sh..."
        mkdir -p "$ACME_HOME"
        curl https://get.acme.sh | sh -s email=myemail@example.com --home "$ACME_HOME"
        mv "$ACME_HOME/acme.sh" "$ACME_SH"
    fi
}

# Inicializa o ambiente
init_env() {
    mkdir -p "$DEFAULT_INSTALL_HOME"
    mkdir -p "$CERT_DIR"
    touch "$LOG_FILE"
    touch "$CRON_FILE"
    install_acme_sh
    echo "Ambiente inicializado para $PROJECT_NAME versao $VERSION"
}

# Funcao para logar as acoes
log_action() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# Funcao para emitir certificado com Let's Encrypt
issue_certificate_letsencrypt() {
    read -p "Insira o dominio para o certificado (exemplo: exemplo.com) ou digite 'v' para voltar: " DOMAIN
    [ "$DOMAIN" = "v" ] && return
    if "$ACME_SH" --issue --server "$CA_LETSENCRYPT" -d "$DOMAIN" --webroot /var/www/html --home "$ACME_HOME"; then
        organize_certificates "$DOMAIN"
        show_certificate_paths "$DOMAIN"
        log_action "Certificado emitido com sucesso para $DOMAIN."
        echo "Certificado emitido com sucesso!"
    else
        log_action "Erro ao emitir certificado para $DOMAIN."
        echo "Erro ao emitir certificado para $DOMAIN."
    fi
    read -p "Pressione v para voltar ao menu..." response
}

# Funcao para emitir certificado com ZeroSSL
issue_certificate_zerossl() {
    read -p "Insira o dominio para o certificado (exemplo: exemplo.com) ou digite 'v' para voltar: " DOMAIN
    [ "$DOMAIN" = "v" ] && return
    if "$ACME_SH" --issue --server "$CA_ZEROSSL" -d "$DOMAIN" --webroot /var/www/html --home "$ACME_HOME"; then
        organize_certificates "$DOMAIN"
        show_certificate_paths "$DOMAIN"
        log_action "Certificado emitido com sucesso para $DOMAIN."
        echo "Certificado emitido com sucesso!"
    else
        log_action "Erro ao emitir certificado para $DOMAIN."
        echo "Erro ao emitir certificado para $DOMAIN."
    fi
    read -p "Pressione v para voltar ao menu..." response
}

# Organiza os certificados criando atalhos ao invés de mover
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
    CERTIFICATES=$(ls -1 "$CERT_DIR")
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
        if "$ACME_SH" --renew -d "$DOMAIN" --home "$ACME_HOME"; then
            organize_certificates "$DOMAIN"
            show_certificate_paths "$DOMAIN"
            log_action "Certificado para $DOMAIN renovado com sucesso."
            echo "Certificado para $DOMAIN renovado com sucesso!"
        else
            log_action "Erro ao renovar certificado para $DOMAIN."
            echo "Erro ao renovar certificado para $DOMAIN."
        fi
    else
        echo "Dominio nao encontrado."
    fi
    read -p "Pressione v para voltar ao menu..." response
}

# Remover certificado
remove_certificate() {
    CERTIFICATES=$(ls -1 "$CERT_DIR")
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
        # Remover atalhos e diretório no .acme.sh
        rm -rf "$CERT_DIR/$DOMAIN"
        rm -rf "$ACME_HOME/${DOMAIN}_ecc"
        log_action "Certificado para $DOMAIN removido."
        echo "Certificado para $DOMAIN removido com sucesso."
    else
        echo "Dominio nao encontrado."
    fi
    read -p "Pressione v para voltar ao menu..." response
}

# Configurar renovacao automatica via cron a cada 89 dias
enable_auto_renewal() {
    CERTIFICATES=$(ls -1 "$CERT_DIR")
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
        (crontab -l 2>/dev/null; echo "0 0 */89 * * \"$ACME_SH\" --renew -d \"$DOMAIN\" --home \"$ACME_HOME\" && \"$ACME_SH\" --reloadcmd") | crontab -
        echo "Renovacao automatica ativada para $DOMAIN a cada 89 dias."
        log_action "Renovacao automatica ativada para $DOMAIN a cada 89 dias."
        echo "$DOMAIN" >> "$CRON_FILE"
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
    crontab -l | grep -v "$DOMAIN" | crontab -
    sed -i "/$DOMAIN/d" "$CRON_FILE"
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
