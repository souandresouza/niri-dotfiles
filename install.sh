#!/usr/bin/env bash
# =============================================================================
# install.sh -- instala os pacotes das listas do niri-dotfiles
# =============================================================================
#
# Uso:
#   ./install.sh                 Instala pacotes oficiais + AUR
#   ./install.sh --pacman        Instala apenas os pacotes oficiais
#   ./install.sh --aur           Instala apenas os pacotes AUR
#   ./install.sh --services      Habilita os serviços de servicos.txt
#   ./install.sh --dry-run       Mostra o que seria feito, sem alterar nada
#   ./install.sh --update-lists  Regenera lista_pacman.txt e lista_aur.txt
#
# As listas são geradas a partir dos pacotes instalados explicitamente:
#   lista_pacman.txt -> pacman -Qenq
#   lista_aur.txt    -> pacman -Qemq

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACMAN_LIST="$REPO_DIR/lista_pacman.txt"
AUR_LIST="$REPO_DIR/lista_aur.txt"
SERVICES_FILE="$REPO_DIR/servicos.txt"

MODE="all"
DRY_RUN=0

usage() {
    sed -n '2,15p' "${BASH_SOURCE[0]}" | sed 's/^#//'
    exit 0
}

log() { printf '[install.sh] %s\n' "$*"; }
warn() { printf '[install.sh] AVISO: %s\n' "$*" >&2; }
err() { printf '[install.sh] ERRO: %s\n' "$*" >&2; exit 1; }

have() { command -v "$1" >/dev/null 2>&1; }

# Lê uma lista ignorando comentários e linhas vazias.
read_list() {
    local file="$1"
    [[ -f "$file" ]] || err "Lista não encontrada: $file"
    grep -v '^\s*#' "$file" | grep -v '^\s*$' || true
}

# Detecta o helper AUR instalado (yay ou paru).
detect_aur_helper() {
    if have yay; then
        echo "yay"
    elif have paru; then
        echo "paru"
    else
        echo ""
    fi
}

# Instala o yay-bin direto do AUR (necessário quando não há helper AUR).
bootstrap_yay() {
    local tmp
    log "Nenhum helper AUR encontrado. Instalando yay-bin via AUR..."
    tmp="$(mktemp -d)"
    git clone --depth 1 "https://aur.archlinux.org/yay-bin.git" "$tmp/yay-bin"
    (cd "$tmp/yay-bin" && makepkg -si --noconfirm)
    rm -rf "$tmp"
}

install_pacman() {
    local pkgs
    pkgs="$(read_list "$PACMAN_LIST")"
    [[ -z "$pkgs" ]] && { log "Lista pacman vazia, nada a fazer."; return; }

    if ! pacman -Qq >/dev/null 2>&1; then
        err "pkgfile/pacman indisponível para verificação."
    fi

    if [[ "$DRY_RUN" -eq 1 ]]; then
        log "Pacotes oficiais a instalar ($(wc -l <<<"$pkgs")):"
        printf '%s\n' "$pkgs" | sed 's/^/   - /'
        return
    fi

    log "Instalando pacotes oficiais ($(wc -l <<<"$pkgs") pacotes)..."
    # shellcheck disable=SC2024
    sudo pacman -S --needed --noconfirm - <<<"$pkgs"
}

install_aur() {
    local helper pkgs
    pkgs="$(read_list "$AUR_LIST")"
    [[ -z "$pkgs" ]] && { log "Lista AUR vazia, nada a fazer."; return; }

    helper="$(detect_aur_helper)"
    if [[ -z "$helper" ]] && [[ "$DRY_RUN" -eq 0 ]]; then
        bootstrap_yay
        helper="yay"
    fi

    if [[ "$DRY_RUN" -eq 1 ]]; then
        log "Pacotes AUR a instalar ($(wc -l <<<"$pkgs") via ${helper:-AUR}):"
        printf '%s\n' "$pkgs" | sed 's/^/   - /'
        return
    fi

    log "Instalando pacotes AUR via $helper ($(wc -l <<<"$pkgs") pacotes)..."
    mapfile -t pkg_arr <<<"$pkgs"
    "$helper" -S --needed --noconfirm "${pkg_arr[@]}"
}

regenerate_lists() {
    log "Regenerando lista_pacman.txt..."
    pacman -Qenq | sort > "$PACMAN_LIST"

    log "Regenerando lista_aur.txt..."
    log "   usa pacman -Qem (explicitos de repositórios estrangeiros)"
    pacman -Qemq | sort > "$AUR_LIST"

    log "Listas atualizadas:"
    log "   pacman: $(wc -l < "$PACMAN_LIST") pacotes"
    log "   AUR:    $(wc -l < "$AUR_LIST") pacotes"
}

install_services() {
    local services
    services="$(read_list "$SERVICES_FILE")"
    [[ -z "$services" ]] && { log "Lista de serviços vazia, nada a fazer."; return; }

    if [[ "$DRY_RUN" -eq 1 ]]; then
        log "Serviços a habilitar:"
        printf '%s\n' "$services" | sed 's/^/   - /'
        return
    fi

    log "Habilitando serviços via systemctl..."
    mapfile -t svc_arr <<<"$services"
    for svc in "${svc_arr[@]}"; do
        # 2>/dev/null para não exigir que um serviço opcional exista em toda máquina
        sudo systemctl enable --now --quiet "$svc" || warn "Falha ao habilitar $svc"
    done
    log "Serviços habilitados."
}

[[ $# -gt 0 ]] || MODE="all"
while (($#)); do
    case "$1" in
        --pacman)   MODE="pacman" ;;
        --aur)      MODE="aur" ;;
        --services) MODE="services" ;;
        --dry-run)  DRY_RUN=1 ;;
        --update-lists|--lists) MODE="lists" ;;
        --help|-h)  usage ;;
        *)          err "Opção desconhecida: $1 (use --help)" ;;
    esac
    shift
done

case "$MODE" in
    pacman)   install_pacman ;;
    aur)      install_aur ;;
    services) install_services ;;
    lists)    regenerate_lists ;;
    *)
        [[ "$(id -u)" -eq 0 ]] && err "Não rode como root (o AUR exige usuário normal)."
        install_pacman
        install_aur
        log "Sugestão: habilite os serviços com ./install.sh --services"
        log "Concluído. Reinicie para finalizar a configuração, se necessário."
        ;;
esac