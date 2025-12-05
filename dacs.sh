#!/usr/bin/env bash

# ===========================================================
# Dolutech Automatic Certificate System (DACS)
# Criado por Lucas Catao de Moraes
# Website: https://dolutech.com
# Versao: 2.0.0 - Sistema Modernizado
# ===========================================================

set -euo pipefail

# ==================== Configuracao do Ambiente ====================
VERSION="2.0.0"
PROJECT_NAME="dacs.sh"
DEFAULT_INSTALL_HOME="${DACS_HOME:-$HOME/.dolutech/$PROJECT_NAME}"
CERT_DIR="$DEFAULT_INSTALL_HOME/certs"
BACKUP_DIR="$DEFAULT_INSTALL_HOME/backups"
CONFIG_DIR="$DEFAULT_INSTALL_HOME/config"
ACME_SH="$DEFAULT_INSTALL_HOME/acme.sh"
ACME_HOME="$DEFAULT_INSTALL_HOME/.acme.sh"
LOG_FILE="$DEFAULT_INSTALL_HOME/dacs.log"
ERROR_LOG="$DEFAULT_INSTALL_HOME/dacs.error.log"
CRON_FILE="$DEFAULT_INSTALL_HOME/dacs_cron.log"
CONFIG_FILE="$CONFIG_DIR/dacs.conf"
MAX_LOG_SIZE=10485760  # 10MB
EXPIRY_WARNING_DAYS=30

# Certificate Authorities
declare -A CA_SERVERS=(
    ["letsencrypt"]="https://acme-v02.api.letsencrypt.org/directory"
    ["letsencrypt-staging"]="https://acme-staging-v02.api.letsencrypt.org/directory"
    ["zerossl"]="https://acme.zerossl.com/v2/DV90"
    ["buypass"]="https://api.buypass.com/acme/directory"
    ["buypass-test"]="https://api.test4.buypass.no/acme/directory"
    ["google"]="https://dv.acme-v02.api.pki.goog/directory"
    ["google-staging"]="https://dv.acme-v02.test-api.pki.goog/directory"
)

# DNS Provider List (simplified)
declare -A DNS_PROVIDERS=(
    ["cloudflare"]="CF_Key CF_Email"
    ["route53"]="AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY"
    ["digitalocean"]="DO_API_KEY"
    ["godaddy"]="GD_Key GD_Secret"
    ["namecheap"]="NAMECHEAP_API_KEY NAMECHEAP_USERNAME"
)

# ==================== Sistema de Cores ====================
if [[ -t 1 ]] && command -v tput &>/dev/null; then
    RED=$(tput setaf 1)
    GREEN=$(tput setaf 2)
    YELLOW=$(tput setaf 3)
    BLUE=$(tput setaf 4)
    MAGENTA=$(tput setaf 5)
    CYAN=$(tput setaf 6)
    WHITE=$(tput setaf 7)
    BOLD=$(tput bold)
    RESET=$(tput sgr0)
else
    RED="" GREEN="" YELLOW="" BLUE="" MAGENTA="" CYAN="" WHITE="" BOLD="" RESET=""
fi

# ==================== Funcoes Auxiliares ====================

# Funcao para exibir mensagens coloridas
print_message() {
    local type="$1"
    shift
    local message="$*"

    case "$type" in
        success)
            echo -e "${GREEN}✓${RESET} ${message}"
            ;;
        error)
            echo -e "${RED}✗${RESET} ${message}" >&2
            ;;
        warning)
            echo -e "${YELLOW}⚠${RESET} ${message}"
            ;;
        info)
            echo -e "${BLUE}ℹ${RESET} ${message}"
            ;;
        header)
            echo -e "\n${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
            echo -e "${CYAN}${BOLD}$message${RESET}"
            echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}\n"
            ;;
        *)
            echo "$message"
            ;;
    esac
}

# Sistema de logging melhorado com niveis
log_message() {
    local level="$1"
    shift
    local message="$*"
    local timestamp
    timestamp=$(date +'%Y-%m-%d %H:%M:%S')

    case "$level" in
        ERROR)
            echo "[$timestamp] [ERROR] $message" >> "$ERROR_LOG"
            ;;
        *)
            echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
            ;;
    esac

    # Rotacao de logs se muito grande
    rotate_logs
}

# Rotacao de logs
rotate_logs() {
    if [[ -f "$LOG_FILE" ]] && [[ $(stat -f%z "$LOG_FILE" 2>/dev/null || stat -c%s "$LOG_FILE" 2>/dev/null || echo 0) -gt $MAX_LOG_SIZE ]]; then
        mv "$LOG_FILE" "$LOG_FILE.old"
        touch "$LOG_FILE"
        log_message "INFO" "Logs rotacionados"
    fi
}

# Validacao de dominio
validate_domain() {
    local domain="$1"
    local domain_regex='^([a-zA-Z0-9]([-a-zA-Z0-9]*[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$|^\*\.([a-zA-Z0-9]([-a-zA-Z0-9]*[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$'

    if [[ $domain =~ $domain_regex ]]; then
        return 0
    else
        return 1
    fi
}

# Validacao de email
validate_email() {
    local email="$1"
    local email_regex='^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'

    if [[ $email =~ $email_regex ]]; then
        return 0
    else
        return 1
    fi
}

# Verificar se certificado existe
certificate_exists() {
    local domain="$1"
    [[ -d "$CERT_DIR/$domain" ]]
}

# Obter informacoes de certificado
get_certificate_info() {
    local domain="$1"
    local cert_file="$CERT_DIR/$domain/$domain.cer"

    if [[ ! -f "$cert_file" ]]; then
        echo "not_found"
        return 1
    fi

    local expiry_date
    expiry_date=$(openssl x509 -enddate -noout -in "$cert_file" 2>/dev/null | cut -d= -f2)

    if [[ -z "$expiry_date" ]]; then
        echo "invalid"
        return 1
    fi

    local expiry_epoch
    expiry_epoch=$(date -d "$expiry_date" +%s 2>/dev/null || date -j -f "%b %d %T %Y %Z" "$expiry_date" +%s 2>/dev/null)
    local now_epoch
    now_epoch=$(date +%s)
    local days_until_expiry=$(( (expiry_epoch - now_epoch) / 86400 ))

    echo "$days_until_expiry|$expiry_date"
    return 0
}

# ==================== Instalacao e Inicializacao ====================

# Instalacao do acme.sh
install_acme_sh() {
    if [[ -f "$ACME_SH" ]]; then
        print_message info "acme.sh ja esta instalado"
        return 0
    fi

    print_message info "Instalando acme.sh..."

    local email
    read -rp "Digite seu email para registro no ACME: " email

    while ! validate_email "$email"; do
        print_message error "Email invalido!"
        read -rp "Digite um email valido: " email
    done

    mkdir -p "$ACME_HOME"

    if curl -s https://get.acme.sh | sh -s email="$email" --home "$ACME_HOME" --install-cronjob; then
        if [[ -f "$ACME_HOME/acme.sh" ]]; then
            ln -sf "$ACME_HOME/acme.sh" "$ACME_SH"
            print_message success "acme.sh instalado com sucesso"
            log_message "INFO" "acme.sh instalado para $email"
            return 0
        fi
    fi

    print_message error "Falha ao instalar acme.sh"
    log_message "ERROR" "Falha na instalacao do acme.sh"
    return 1
}

# Inicializar ambiente
init_env() {
    mkdir -p "$DEFAULT_INSTALL_HOME" "$CERT_DIR" "$BACKUP_DIR" "$CONFIG_DIR"
    touch "$LOG_FILE" "$ERROR_LOG" "$CRON_FILE"

    if [[ ! -f "$CONFIG_FILE" ]]; then
        cat > "$CONFIG_FILE" << 'EOF'
# Configuracao DACS
DEFAULT_CA="letsencrypt"
DEFAULT_CHALLENGE="webroot"
DEFAULT_WEBROOT="/var/www/html"
AUTO_BACKUP="true"
NOTIFICATION_EMAIL=""
EOF
    fi

    install_acme_sh
    print_message success "Ambiente inicializado - DACS v$VERSION"
    log_message "INFO" "Ambiente inicializado - versao $VERSION"
}

# ==================== Funcoes de Certificados ====================

# Emitir certificado
issue_certificate() {
    print_message header "EMISSAO DE CERTIFICADO"

    # Selecionar CA
    print_message info "Certificate Authorities disponiveis:"
    local ca_options=("letsencrypt" "zerossl" "buypass" "google")
    for i in "${!ca_options[@]}"; do
        echo "  $((i+1)). ${ca_options[$i]}"
    done

    read -rp "Escolha a CA (1-${#ca_options[@]}) [1]: " ca_choice
    ca_choice=${ca_choice:-1}
    local ca="${ca_options[$((ca_choice-1))]}"

    # Selecionar metodo de validacao
    print_message info "Metodos de validacao:"
    echo "  1. Webroot (HTTP-01)"
    echo "  2. DNS (DNS-01)"
    echo "  3. Standalone"

    read -rp "Escolha o metodo (1-3) [1]: " method_choice
    method_choice=${method_choice:-1}

    # Input do dominio
    read -rp "Digite o dominio (ex: example.com ou *.example.com): " domain

    while ! validate_domain "$domain"; do
        print_message error "Dominio invalido!"
        read -rp "Digite um dominio valido: " domain
    done

    # Adicionar dominios adicionais
    local extra_domains=()
    read -rp "Adicionar dominios adicionais? (s/n) [n]: " add_extra

    if [[ "${add_extra,,}" == "s" ]]; then
        while true; do
            read -rp "Digite dominio adicional (ou Enter para continuar): " extra_domain
            [[ -z "$extra_domain" ]] && break

            if validate_domain "$extra_domain"; then
                extra_domains+=("$extra_domain")
                print_message success "Adicionado: $extra_domain"
            else
                print_message error "Dominio invalido, ignorado"
            fi
        done
    fi

    # Construir comando
    local cmd=("$ACME_SH" --issue --server "${CA_SERVERS[$ca]}" -d "$domain")

    for extra in "${extra_domains[@]}"; do
        cmd+=(-d "$extra")
    done

    case "$method_choice" in
        1)
            read -rp "Caminho do webroot [/var/www/html]: " webroot
            webroot=${webroot:-/var/www/html}
            cmd+=(--webroot "$webroot")
            ;;
        2)
            print_message info "Providers DNS disponiveis:"
            local dns_list=($(printf '%s\n' "${!DNS_PROVIDERS[@]}" | sort))
            for i in "${!dns_list[@]}"; do
                echo "  $((i+1)). ${dns_list[$i]}"
            done

            read -rp "Escolha o provider DNS (1-${#dns_list[@]}): " dns_choice
            local dns_provider="${dns_list[$((dns_choice-1))]}"

            # Pedir credenciais DNS
            print_message warning "Configure as variaveis de ambiente necessarias:"
            echo "  ${DNS_PROVIDERS[$dns_provider]}"
            read -rp "Pressione Enter apos configurar as variaveis..."

            cmd+=(--dns "dns_$dns_provider")
            ;;
        3)
            cmd+=(--standalone)
            ;;
    esac

    cmd+=(--home "$ACME_HOME")

    print_message info "Emitindo certificado..."

    if "${cmd[@]}"; then
        organize_certificates "$domain"
        show_certificate_paths "$domain"

        if [[ "${AUTO_BACKUP:-true}" == "true" ]]; then
            backup_certificate "$domain"
        fi

        print_message success "Certificado emitido com sucesso!"
        log_message "INFO" "Certificado emitido para $domain usando $ca"
    else
        print_message error "Falha ao emitir certificado"
        log_message "ERROR" "Falha ao emitir certificado para $domain"
    fi

    pause
}

# Organizar certificados
organize_certificates() {
    local domain="$1"
    local domain_cert_dir="$CERT_DIR/$domain"
    mkdir -p "$domain_cert_dir"

    # Criar links simbolicos
    local cert_path="$ACME_HOME/${domain}_ecc"
    [[ ! -d "$cert_path" ]] && cert_path="$ACME_HOME/$domain"

    if [[ -d "$cert_path" ]]; then
        ln -sf "$cert_path/$domain.key" "$domain_cert_dir/"
        ln -sf "$cert_path/$domain.cer" "$domain_cert_dir/"
        ln -sf "$cert_path/fullchain.cer" "$domain_cert_dir/"
        ln -sf "$cert_path/ca.cer" "$domain_cert_dir/"

        # Salvar metadata
        cat > "$domain_cert_dir/metadata.txt" << EOF
Domain: $domain
Issued: $(date)
CA: ${ca:-unknown}
Method: ${method_choice:-unknown}
EOF

        log_message "INFO" "Certificado organizado em $domain_cert_dir"
    fi
}

# Mostrar caminhos do certificado
show_certificate_paths() {
    local domain="$1"
    local domain_cert_dir="$CERT_DIR/$domain"

    print_message header "CERTIFICADO EMITIDO"
    echo "${BOLD}Dominio:${RESET} $domain"
    echo "${BOLD}Certificado:${RESET} $domain_cert_dir/$domain.cer"
    echo "${BOLD}Chave Privada:${RESET} $domain_cert_dir/$domain.key"
    echo "${BOLD}CA:${RESET} $domain_cert_dir/ca.cer"
    echo "${BOLD}Cadeia Completa:${RESET} $domain_cert_dir/fullchain.cer"
}

# Listar certificados com informacoes detalhadas
list_certificates() {
    print_message header "CERTIFICADOS INSTALADOS"

    if [[ ! -d "$CERT_DIR" ]] || [[ -z "$(ls -A "$CERT_DIR" 2>/dev/null)" ]]; then
        print_message warning "Nenhum certificado encontrado"
        pause
        return
    fi

    local cert_count=0
    for domain_dir in "$CERT_DIR"/*; do
        [[ ! -d "$domain_dir" ]] && continue

        local domain
        domain=$(basename "$domain_dir")
        cert_count=$((cert_count + 1))

        echo -e "\n${BOLD}[$cert_count] $domain${RESET}"

        local cert_info
        cert_info=$(get_certificate_info "$domain")

        if [[ $? -eq 0 ]]; then
            local days_left expiry_date
            IFS='|' read -r days_left expiry_date <<< "$cert_info"

            if [[ $days_left -lt 0 ]]; then
                echo "  ${RED}Status: EXPIRADO${RESET}"
            elif [[ $days_left -lt $EXPIRY_WARNING_DAYS ]]; then
                echo "  ${YELLOW}Status: Expira em breve${RESET}"
            else
                echo "  ${GREEN}Status: Valido${RESET}"
            fi

            echo "  Expira em: $days_left dias ($expiry_date)"
        else
            echo "  ${RED}Status: Certificado nao encontrado ou invalido${RESET}"
        fi

        if [[ -f "$domain_dir/metadata.txt" ]]; then
            echo "  $(grep 'Issued:' "$domain_dir/metadata.txt" | sed 's/^//')"
        fi
    done

    if [[ $cert_count -eq 0 ]]; then
        print_message warning "Nenhum certificado encontrado"
    fi

    pause
}

# Renovar certificado
renew_certificate() {
    print_message header "RENOVACAO DE CERTIFICADO"

    local domain
    domain=$(select_certificate "renovar")
    [[ -z "$domain" ]] && return

    print_message info "Renovando certificado para $domain..."

    if "$ACME_SH" --renew -d "$domain" --home "$ACME_HOME" --force; then
        organize_certificates "$domain"

        if [[ "${AUTO_BACKUP:-true}" == "true" ]]; then
            backup_certificate "$domain"
        fi

        print_message success "Certificado renovado com sucesso!"
        log_message "INFO" "Certificado renovado para $domain"
    else
        print_message error "Falha ao renovar certificado"
        log_message "ERROR" "Falha ao renovar certificado para $domain"
    fi

    pause
}

# Remover certificado
remove_certificate() {
    print_message header "REMOCAO DE CERTIFICADO"

    local domain
    domain=$(select_certificate "remover")
    [[ -z "$domain" ]] && return

    read -rp "Tem certeza que deseja remover $domain? (s/n): " confirm

    if [[ "${confirm,,}" != "s" ]]; then
        print_message info "Operacao cancelada"
        pause
        return
    fi

    # Backup antes de remover
    backup_certificate "$domain"

    # Remover do acme.sh
    "$ACME_SH" --remove -d "$domain" --home "$ACME_HOME" 2>/dev/null || true

    # Remover diretorios
    rm -rf "$CERT_DIR/$domain"
    rm -rf "$ACME_HOME/${domain}_ecc"
    rm -rf "$ACME_HOME/$domain"

    # Remover do cron
    deactivate_auto_renewal "$domain"

    print_message success "Certificado removido com sucesso"
    log_message "INFO" "Certificado removido para $domain"

    pause
}

# Selecionar certificado
select_certificate() {
    local action="${1:-selecionar}"

    if [[ ! -d "$CERT_DIR" ]] || [[ -z "$(ls -A "$CERT_DIR" 2>/dev/null)" ]]; then
        print_message warning "Nenhum certificado encontrado"
        pause
        return 1
    fi

    local domains=()
    for domain_dir in "$CERT_DIR"/*; do
        [[ ! -d "$domain_dir" ]] && continue
        domains+=("$(basename "$domain_dir")")
    done

    if [[ ${#domains[@]} -eq 0 ]]; then
        print_message warning "Nenhum certificado disponivel"
        pause
        return 1
    fi

    echo "Certificados disponiveis para $action:"
    for i in "${!domains[@]}"; do
        echo "  $((i+1)). ${domains[$i]}"
    done
    echo "  0. Cancelar"

    read -rp "Escolha (0-${#domains[@]}): " choice

    if [[ "$choice" == "0" ]] || [[ -z "$choice" ]]; then
        return 1
    fi

    if [[ "$choice" =~ ^[0-9]+$ ]] && [[ $choice -ge 1 ]] && [[ $choice -le ${#domains[@]} ]]; then
        echo "${domains[$((choice-1))]}"
        return 0
    else
        print_message error "Opcao invalida"
        pause
        return 1
    fi
}

# ==================== Renovacao Automatica ====================

# Ativar renovacao automatica
enable_auto_renewal() {
    print_message header "RENOVACAO AUTOMATICA"

    local domain
    domain=$(select_certificate "ativar renovacao automatica")
    [[ -z "$domain" ]] && return

    # Verificar se ja existe
    if crontab -l 2>/dev/null | grep -q "$domain"; then
        print_message warning "Renovacao automatica ja ativada para $domain"
        pause
        return
    fi

    local cron_cmd="0 0 */60 * * \"$ACME_SH\" --renew -d \"$domain\" --home \"$ACME_HOME\" >> \"$LOG_FILE\" 2>&1"

    (crontab -l 2>/dev/null; echo "$cron_cmd") | crontab -
    echo "$domain" >> "$CRON_FILE"

    print_message success "Renovacao automatica ativada para $domain (a cada 60 dias)"
    log_message "INFO" "Renovacao automatica ativada para $domain"

    pause
}

# Ver renovacoes automaticas
view_auto_renewals() {
    print_message header "RENOVACOES AUTOMATICAS"

    if [[ ! -s "$CRON_FILE" ]]; then
        print_message warning "Nenhuma renovacao automatica configurada"
        pause
        return
    fi

    local count=0
    while IFS= read -r domain; do
        [[ -z "$domain" ]] && continue
        count=$((count + 1))

        local cert_info
        cert_info=$(get_certificate_info "$domain")

        echo -e "\n${BOLD}[$count] $domain${RESET}"

        if [[ $? -eq 0 ]]; then
            local days_left expiry_date
            IFS='|' read -r days_left expiry_date <<< "$cert_info"
            echo "  Expira em: $days_left dias"
        fi
    done < "$CRON_FILE"

    read -rp "Deseja desativar alguma renovacao? (s/n): " response

    if [[ "${response,,}" == "s" ]]; then
        local domains
        mapfile -t domains < "$CRON_FILE"

        for i in "${!domains[@]}"; do
            echo "  $((i+1)). ${domains[$i]}"
        done

        read -rp "Escolha o numero (1-${#domains[@]}): " choice

        if [[ "$choice" =~ ^[0-9]+$ ]] && [[ $choice -ge 1 ]] && [[ $choice -le ${#domains[@]} ]]; then
            deactivate_auto_renewal "${domains[$((choice-1))]}"
        fi
    fi

    pause
}

# Desativar renovacao automatica
deactivate_auto_renewal() {
    local domain="$1"

    crontab -l 2>/dev/null | grep -v "$domain" | crontab - || true
    sed -i.bak "/^${domain}$/d" "$CRON_FILE" 2>/dev/null || sed -i '' "/^${domain}$/d" "$CRON_FILE" 2>/dev/null

    print_message success "Renovacao automatica desativada para $domain"
    log_message "INFO" "Renovacao automatica desativada para $domain"
}

# ==================== Backup ====================

# Fazer backup de certificado
backup_certificate() {
    local domain="$1"
    local backup_subdir="$BACKUP_DIR/$domain"
    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_file="$backup_subdir/backup_${timestamp}.tar.gz"

    mkdir -p "$backup_subdir"

    if tar -czf "$backup_file" -C "$CERT_DIR" "$domain" 2>/dev/null; then
        print_message success "Backup criado: $backup_file"
        log_message "INFO" "Backup criado para $domain"

        # Manter apenas os 5 backups mais recentes
        local backup_count
        backup_count=$(find "$backup_subdir" -name "backup_*.tar.gz" | wc -l)

        if [[ $backup_count -gt 5 ]]; then
            find "$backup_subdir" -name "backup_*.tar.gz" | sort | head -n $((backup_count - 5)) | xargs rm -f
        fi
    else
        print_message error "Falha ao criar backup"
        log_message "ERROR" "Falha ao criar backup para $domain"
    fi
}

# Listar backups
list_backups() {
    print_message header "BACKUPS DE CERTIFICADOS"

    if [[ ! -d "$BACKUP_DIR" ]] || [[ -z "$(ls -A "$BACKUP_DIR" 2>/dev/null)" ]]; then
        print_message warning "Nenhum backup encontrado"
        pause
        return
    fi

    for domain_backup in "$BACKUP_DIR"/*; do
        [[ ! -d "$domain_backup" ]] && continue

        local domain
        domain=$(basename "$domain_backup")

        echo -e "\n${BOLD}$domain${RESET}"

        local backup_files
        backup_files=$(find "$domain_backup" -name "backup_*.tar.gz" | sort -r)

        if [[ -z "$backup_files" ]]; then
            echo "  Nenhum backup"
        else
            echo "$backup_files" | while read -r backup_file; do
                local size
                size=$(du -h "$backup_file" | cut -f1)
                local filename
                filename=$(basename "$backup_file")
                echo "  - $filename ($size)"
            done
        fi
    done

    pause
}

# ==================== Deploy ====================

# Deploy para servidor web
deploy_certificate() {
    print_message header "DEPLOY DE CERTIFICADO"

    local domain
    domain=$(select_certificate "fazer deploy")
    [[ -z "$domain" ]] && return

    print_message info "Servidores Web suportados:"
    echo "  1. Nginx"
    echo "  2. Apache"
    echo "  3. Personalizado"

    read -rp "Escolha o servidor (1-3): " server_choice

    local cert_path="$CERT_DIR/$domain"

    case "$server_choice" in
        1)
            deploy_nginx "$domain" "$cert_path"
            ;;
        2)
            deploy_apache "$domain" "$cert_path"
            ;;
        3)
            deploy_custom "$domain" "$cert_path"
            ;;
        *)
            print_message error "Opcao invalida"
            ;;
    esac

    pause
}

# Deploy Nginx
deploy_nginx() {
    local domain="$1"
    local cert_path="$2"

    print_message info "Exemplo de configuracao Nginx:"

    cat << EOF

${CYAN}server {
    listen 443 ssl http2;
    server_name $domain;

    ssl_certificate $cert_path/fullchain.cer;
    ssl_certificate_key $cert_path/$domain.key;

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;

    # Seu restante da configuracao aqui
}${RESET}

EOF

    read -rp "Deseja recarregar o Nginx? (s/n): " reload

    if [[ "${reload,,}" == "s" ]]; then
        if command -v nginx &>/dev/null; then
            if sudo nginx -t && sudo systemctl reload nginx; then
                print_message success "Nginx recarregado com sucesso"
                log_message "INFO" "Nginx recarregado para $domain"
            else
                print_message error "Falha ao recarregar Nginx"
            fi
        else
            print_message error "Nginx nao encontrado"
        fi
    fi
}

# Deploy Apache
deploy_apache() {
    local domain="$1"
    local cert_path="$2"

    print_message info "Exemplo de configuracao Apache:"

    cat << EOF

${CYAN}<VirtualHost *:443>
    ServerName $domain

    SSLEngine on
    SSLCertificateFile $cert_path/$domain.cer
    SSLCertificateKeyFile $cert_path/$domain.key
    SSLCertificateChainFile $cert_path/ca.cer

    # Seu restante da configuracao aqui
</VirtualHost>${RESET}

EOF

    read -rp "Deseja recarregar o Apache? (s/n): " reload

    if [[ "${reload,,}" == "s" ]]; then
        if command -v apache2 &>/dev/null; then
            if sudo apache2ctl configtest && sudo systemctl reload apache2; then
                print_message success "Apache recarregado com sucesso"
                log_message "INFO" "Apache recarregado para $domain"
            else
                print_message error "Falha ao recarregar Apache"
            fi
        elif command -v httpd &>/dev/null; then
            if sudo httpd -t && sudo systemctl reload httpd; then
                print_message success "Apache recarregado com sucesso"
                log_message "INFO" "Apache recarregado para $domain"
            else
                print_message error "Falha ao recarregar Apache"
            fi
        else
            print_message error "Apache nao encontrado"
        fi
    fi
}

# Deploy personalizado
deploy_custom() {
    local domain="$1"
    local cert_path="$2"

    print_message info "Caminhos dos certificados:"
    echo "  Certificado: $cert_path/fullchain.cer"
    echo "  Chave Privada: $cert_path/$domain.key"
    echo "  CA: $cert_path/ca.cer"

    read -rp "Digite o comando de deploy personalizado (ou Enter para pular): " custom_cmd

    if [[ -n "$custom_cmd" ]]; then
        if eval "$custom_cmd"; then
            print_message success "Deploy personalizado executado com sucesso"
            log_message "INFO" "Deploy personalizado para $domain: $custom_cmd"
        else
            print_message error "Falha no deploy personalizado"
        fi
    fi
}

# ==================== Gerenciamento de Logs ====================

# Ver logs
view_logs() {
    print_message header "LOGS DO SISTEMA"

    echo "1. Ver todos os logs"
    echo "2. Ver ultimas 50 linhas"
    echo "3. Ver logs de erro"
    echo "4. Buscar nos logs"

    read -rp "Escolha (1-4): " log_choice

    case "$log_choice" in
        1)
            if [[ -s "$LOG_FILE" ]]; then
                less "$LOG_FILE"
            else
                print_message warning "Nenhum log encontrado"
            fi
            ;;
        2)
            if [[ -s "$LOG_FILE" ]]; then
                tail -n 50 "$LOG_FILE"
            else
                print_message warning "Nenhum log encontrado"
            fi
            ;;
        3)
            if [[ -s "$ERROR_LOG" ]]; then
                less "$ERROR_LOG"
            else
                print_message warning "Nenhum log de erro encontrado"
            fi
            ;;
        4)
            read -rp "Digite o termo de busca: " search_term
            if [[ -s "$LOG_FILE" ]]; then
                grep -i "$search_term" "$LOG_FILE" || print_message warning "Nenhum resultado encontrado"
            else
                print_message warning "Nenhum log encontrado"
            fi
            ;;
        *)
            print_message error "Opcao invalida"
            ;;
    esac

    pause
}

# Limpar logs
clear_logs() {
    read -rp "Tem certeza que deseja limpar os logs? (s/n): " confirm

    if [[ "${confirm,,}" == "s" ]]; then
        > "$LOG_FILE"
        > "$ERROR_LOG"
        print_message success "Logs limpos"
        log_message "INFO" "Logs limpos pelo usuario"
    else
        print_message info "Operacao cancelada"
    fi

    pause
}

# ==================== Modo CLI (Nao-Interativo) ====================

# Funcao de ajuda
show_help() {
    cat << EOF
${BOLD}Dolutech Automatic Certificate System (DACS) v$VERSION${RESET}

${BOLD}USO:${RESET}
    $0 [comando] [opcoes]

${BOLD}COMANDOS:${RESET}
    issue       Emitir novo certificado
    renew       Renovar certificado existente
    remove      Remover certificado
    list        Listar todos os certificados
    info        Mostrar informacoes de certificado especifico
    backup      Fazer backup de certificado
    deploy      Deploy de certificado
    enable-auto Ativar renovacao automatica
    logs        Ver logs
    version     Mostrar versao
    help        Mostrar esta ajuda

${BOLD}OPCOES (issue):${RESET}
    -d, --domain DOMAIN        Dominio do certificado
    -c, --ca CA                Certificate Authority (letsencrypt, zerossl, buypass, google)
    -w, --webroot PATH         Caminho do webroot para validacao HTTP
    --dns PROVIDER             Provider DNS para validacao DNS
    --standalone               Usar modo standalone

${BOLD}EXEMPLOS:${RESET}
    $0 issue -d example.com -c letsencrypt -w /var/www/html
    $0 renew -d example.com
    $0 list
    $0 enable-auto -d example.com

EOF
}

# Parser de argumentos CLI
parse_cli_args() {
    local command="$1"
    shift

    case "$command" in
        issue)
            cli_issue "$@"
            ;;
        renew)
            cli_renew "$@"
            ;;
        remove)
            cli_remove "$@"
            ;;
        list)
            list_certificates
            ;;
        logs)
            view_logs
            ;;
        version)
            echo "DACS v$VERSION"
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            print_message error "Comando desconhecido: $command"
            show_help
            exit 1
            ;;
    esac
}

# CLI issue
cli_issue() {
    local domain="" ca="letsencrypt" webroot="/var/www/html" dns_provider="" standalone=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -d|--domain)
                domain="$2"
                shift 2
                ;;
            -c|--ca)
                ca="$2"
                shift 2
                ;;
            -w|--webroot)
                webroot="$2"
                shift 2
                ;;
            --dns)
                dns_provider="$2"
                shift 2
                ;;
            --standalone)
                standalone=true
                shift
                ;;
            *)
                print_message error "Opcao desconhecida: $1"
                exit 1
                ;;
        esac
    done

    if [[ -z "$domain" ]]; then
        print_message error "Dominio e obrigatorio: -d DOMAIN"
        exit 1
    fi

    if ! validate_domain "$domain"; then
        print_message error "Dominio invalido: $domain"
        exit 1
    fi

    local cmd=("$ACME_SH" --issue --server "${CA_SERVERS[$ca]}" -d "$domain")

    if [[ -n "$dns_provider" ]]; then
        cmd+=(--dns "dns_$dns_provider")
    elif [[ "$standalone" == true ]]; then
        cmd+=(--standalone)
    else
        cmd+=(--webroot "$webroot")
    fi

    cmd+=(--home "$ACME_HOME")

    if "${cmd[@]}"; then
        organize_certificates "$domain"
        print_message success "Certificado emitido para $domain"
    else
        print_message error "Falha ao emitir certificado"
        exit 1
    fi
}

# CLI renew
cli_renew() {
    local domain=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -d|--domain)
                domain="$2"
                shift 2
                ;;
            *)
                print_message error "Opcao desconhecida: $1"
                exit 1
                ;;
        esac
    done

    if [[ -z "$domain" ]]; then
        print_message error "Dominio e obrigatorio: -d DOMAIN"
        exit 1
    fi

    if "$ACME_SH" --renew -d "$domain" --home "$ACME_HOME" --force; then
        organize_certificates "$domain"
        print_message success "Certificado renovado para $domain"
    else
        print_message error "Falha ao renovar certificado"
        exit 1
    fi
}

# CLI remove
cli_remove() {
    local domain=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -d|--domain)
                domain="$2"
                shift 2
                ;;
            *)
                print_message error "Opcao desconhecida: $1"
                exit 1
                ;;
        esac
    done

    if [[ -z "$domain" ]]; then
        print_message error "Dominio e obrigatorio: -d DOMAIN"
        exit 1
    fi

    "$ACME_SH" --remove -d "$domain" --home "$ACME_HOME" 2>/dev/null || true
    rm -rf "$CERT_DIR/$domain"
    rm -rf "$ACME_HOME/${domain}_ecc"
    rm -rf "$ACME_HOME/$domain"

    print_message success "Certificado removido para $domain"
}

# ==================== Menu Principal ====================

# Funcao de pausa
pause() {
    read -rp "Pressione Enter para continuar..."
}

# Menu principal
menu() {
    while true; do
        clear
        cat << EOF
${CYAN}${BOLD}╔════════════════════════════════════════════╗
║   Dolutech Automatic Certificate System   ║
║            Versao: $VERSION                  ║
╚════════════════════════════════════════════╝${RESET}

${BOLD}GERENCIAMENTO DE CERTIFICADOS${RESET}
  ${GREEN}1${RESET}. Emitir Certificado
  ${GREEN}2${RESET}. Listar Certificados
  ${GREEN}3${RESET}. Renovar Certificado
  ${GREEN}4${RESET}. Remover Certificado

${BOLD}AUTOMACAO${RESET}
  ${YELLOW}5${RESET}. Ativar Renovacao Automatica
  ${YELLOW}6${RESET}. Ver Renovacoes Automaticas

${BOLD}BACKUP E DEPLOY${RESET}
  ${BLUE}7${RESET}. Fazer Backup de Certificado
  ${BLUE}8${RESET}. Listar Backups
  ${BLUE}9${RESET}. Deploy de Certificado

${BOLD}SISTEMA${RESET}
  ${MAGENTA}10${RESET}. Ver Logs
  ${MAGENTA}11${RESET}. Limpar Logs
  ${RED}0${RESET}. Sair

EOF
        read -rp "Escolha uma opcao: " option

        case "$option" in
            1) issue_certificate ;;
            2) list_certificates ;;
            3) renew_certificate ;;
            4) remove_certificate ;;
            5) enable_auto_renewal ;;
            6) view_auto_renewals ;;
            7)
                local domain
                domain=$(select_certificate "fazer backup")
                [[ -n "$domain" ]] && backup_certificate "$domain" && pause
                ;;
            8) list_backups ;;
            9) deploy_certificate ;;
            10) view_logs ;;
            11) clear_logs ;;
            0)
                print_message success "Obrigado por usar o DACS!"
                echo "Acesse ${CYAN}https://dolutech.com${RESET} para mais informacoes"
                exit 0
                ;;
            *)
                print_message error "Opcao invalida"
                pause
                ;;
        esac
    done
}

# ==================== Main ====================

main() {
    # Comandos que nao precisam de inicializacao
    if [[ $# -gt 0 ]]; then
        case "$1" in
            help|--help|-h|version)
                parse_cli_args "$@"
                return 0
                ;;
        esac
    fi

    # Inicializar ambiente
    init_env

    if [[ $# -eq 0 ]]; then
        # Modo interativo
        menu
    else
        # Modo CLI
        parse_cli_args "$@"
    fi
}

main "$@"
