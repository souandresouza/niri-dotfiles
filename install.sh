#!/usr/bin/env bash
# =============================================================================
# install.sh -- instala os pacotes das listas do niri-dotfiles
# =============================================================================
#
# Uso:
#   ./install.sh                 Instala pacotes oficiais + AUR
#   ./install.sh --pacman        Instala apenas os pacotes oficiais
#   ./install.sh --aur           Instala apenas os pacotes AUR
#   ./install.sh --cadrocfile    Clona/atualiza e instala o cadrocfile (meu file manager)
#   ./install.sh --ruwall       Clona/atualiza e instala o ruwall (gerador de paleta)
#   ./install.sh --services      Habilita os serviços de servicos.txt
#   ./install.sh --firefox       Aplica ajustes do Firefox para o Niri
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
    sed -n '2,16p' "${BASH_SOURCE[0]}" | sed 's/^#//'
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
        --cadrocfile) MODE="cadrocfile" ;;
        --ruwall) MODE="ruwall" ;;
        --services) MODE="services" ;;
        --firefox)  MODE="firefox" ;;
        --dry-run)  DRY_RUN=1 ;;
        --update-lists|--lists) MODE="lists" ;;
        --help|-h)  usage ;;
        *)          err "Opção desconhecida: $1 (use --help)" ;;
    esac
    shift
done

# -----------------------------------------------------------------------------
# 13. CADROCFILE (GERENCIADOR DE ARQUIVOS)
# -----------------------------------------------------------------------------
install_cadrocfile() {
    local repo_dir="$HOME/cadrocfile"
    local cadroc_install

    log "Instalando cadrocfile (meu gerenciador de arquivos)..."

    if [[ -d "$repo_dir" ]]; then
        log "Repositório cadrocfile já existe em $repo_dir"
    else
        if [[ "$DRY_RUN" -eq 1 ]]; then
            log "Clonaria https://github.com/souandresouza/cadrocfile.git em $repo_dir"
        else
            log "Clonando https://github.com/souandresouza/cadrocfile.git..."
            git clone --depth 1 "https://github.com/souandresouza/cadrocfile.git" "$repo_dir"
        fi
    fi

    cadroc_install="$repo_dir/install.sh"
    [[ -f "$cadroc_install" ]] || err "Script de instalação não encontrado: $cadroc_install"

    if [[ "$DRY_RUN" -eq 1 ]]; then
        log "Executaria: $cadroc_install (detectando binário vs source)"
        return
    fi

    # Executa o instalador do cadrocfile. Ele detecta o sistema e
    # instala na melhor forma (binário pré-compilado ou compila do fonte)
    (
        cd "$repo_dir"
        # Usa o prefixo ~/.local por padrão para não exigir root
        bash "$cadroc_install" --prefix "${HOME}/.local" "${ASSUME_YES:+--yes}"
    )

    if command -v cadrocfile >/dev/null 2>&1; then
        log "cadrocfile instalado com sucesso: $(command -v cadrocfile)"
    else
        warn "cadrocfile pode não estar no PATH. Verifique em ~/.local/bin"
    fi
}

# -----------------------------------------------------------------------------
# 14. RUWALL (GERADOR DE PALETA DE CORES)
# -----------------------------------------------------------------------------
install_ruwall() {
    local repo_dir="$HOME/ruwall"
    local bin_out="$repo_dir/target/release/ruwall"

    log "Instalando ruwall (gerador de paleta de cores)..."

    if [[ -d "$repo_dir" ]]; then
        log "Repositório ruwall já existe em $repo_dir"
    else
        if [[ "$DRY_RUN" -eq 1 ]]; then
            log "Clonaria https://github.com/souandresouza/ruwall.git em $repo_dir"
        else
            log "Clonando https://github.com/souandresouza/ruwall.git..."
            git clone --depth 1 "https://github.com/souandresouza/ruwall.git" "$repo_dir"
        fi
    fi

    if [[ "$DRY_RUN" -eq 1 ]]; then
        log "Compilaria com: cargo build --release"
        log "Instalaria em: $HOME/.local/bin/ruwall"
        return
    fi

    ensure_cargo

    mkdir -p "$HOME/.local/bin"

    (
        cd "$repo_dir"
        log "Compilando ruwall (pode demorar alguns minutos)..."
        cargo build --release
    )

    [[ -f "$bin_out" ]] || err "Binário não encontrado após compilação: $bin_out"

    install -m755 "$bin_out" "$HOME/.local/bin/ruwall"
    log "ruwall instalado em $HOME/.local/bin/ruwall"

    if command -v ruwall >/dev/null 2>&1; then
        log "Versão: $(ruwall -v 2>&1 | head -n1)"
    else
        warn "ruwall pode não estar no PATH. Verifique em ~/.local/bin"
    fi
}

# -----------------------------------------------------------------------------
# 0. CHECAGENS PARA ARCH PURO
# -----------------------------------------------------------------------------
check_build_deps() {
    local missing=()

    if [[ "$(id -u)" -eq 0 ]]; then
        return
    fi

    # Dependências mínimas para compilar/instalar AUR e meus projetos
    if ! pacman -Qq base-devel >/dev/null 2>&1; then
        missing+=("base-devel")
    fi

    if ! command -v git >/dev/null 2>&1; then
        missing+=("git")
    fi

    if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1; then
        missing+=("curl")
    fi

    if ((${#missing[@]} > 0)); then
        warn "Dependências para build/AUR ausentes: ${missing[*]}"
        warn "No Arch Linux puro você pode instalar com:"
        warn "  sudo pacman -S --needed ${missing[*]}"
        warn "Se já estiverem instalados, essa verificação pode falhar caso não sejam explícitos."
    fi
}

ensure_cargo() {
    if command -v cargo >/dev/null 2>&1; then
        return 0
    fi

    warn "Rust/Cargo não encontrado. Necessário para compilar o ruwall."
    warn "Opções:"
    warn "  - rustup (recomendado): curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh"
    warn "  - pacman (mais simples): sudo pacman -S --needed rust"

    if have pacman && [[ "$(id -u)" -ne 0 ]]; then
        if [[ "$DRY_RUN" -eq 1 ]]; then
            log "[dry-run] Instalaria rust via pacman se necessário"
            return 0
        fi

        read -r -p "[install.sh] Tentar instalar 'rust' via pacman agora? [y/N] " ans </dev/tty || ans="n"
        case "$ans" in
            [Yy]*) 
                log "Instalando rust..."
                sudo pacman -S --needed --noconfirm rust || warn "Falha ao instalar rust via pacman. Instale manualmente com rustup."
                ;;
            *) 
                err "Instale Rust/Cargo para compilar o ruwall (use rustup ou pacman)."
                ;;
        esac
    else
        err "Instale Rust/Cargo (rustup ou pacman) e rode novamente."
    fi

    command -v cargo >/dev/null 2>&1 || err "cargo ainda não encontrado no PATH após tentativa de instalação."
}

# -----------------------------------------------------------------------------
# 15. FIREFOX (AJUSTES PARA O NIRI)
# -----------------------------------------------------------------------------
# O xdg-desktop-portal-gtk não consegue criar a janela do file chooser no Niri
# (compositor não-GNOME): "Unhandled parent window type" / "Failed to associate
# portal window". Com isso, "Salvar imagem como..." no Firefox não abre nada.
# Desabilitar o file picker do portal faz o Firefox usar o diálogo GTK nativo,
# que funciona em qualquer compositor.
install_firefox() {
    local root base prefs_dir changed=0

    if [[ "$DRY_RUN" -eq 1 ]]; then
        log "Aplicaria widget.use-xdg-desktop-portal.file-picker=0 nos perfis do Firefox"
        return
    fi

    # Firefox local usa ~/.mozilla/firefox (padrão) OU ~/.config/mozilla/firefox
    # (quando XDG_CONFIG_HOME é respeitado). Cobre os dois.
    for root in "$HOME/.mozilla/firefox" "$HOME/.config/mozilla/firefox"; do
        [[ -d "$root" ]] || continue
        for prefs_dir in "$root"/*.default*; do
            [[ -d "$prefs_dir" ]] || continue

            if grep -q 'use-xdg-desktop-portal.file-picker' "$prefs_dir/user.js" 2>/dev/null; then
                log "Firefox já ajustado: $prefs_dir"
                continue
            fi

            printf '%s\n' \
                'user_pref("widget.use-xdg-desktop-portal.file-picker", 0);' \
                >> "$prefs_dir/user.js"
            log "Ajuste aplicado no Firefox: $prefs_dir"
            changed=1
        done
    done

    if [[ "$changed" -eq 0 ]]; then
        log "Nenhum perfil do Firefox encontrado para ajustar (ok se não usa Firefox)."
    fi
}

# -----------------------------------------------------------------------------
# EXECUÇÃO (após todas as funções estarem definidas)
# -----------------------------------------------------------------------------
case "$MODE" in
    pacman)     check_build_deps; install_pacman ;;
    aur)        check_build_deps; install_aur ;;
    cadrocfile) check_build_deps; install_cadrocfile ;;
    ruwall)     check_build_deps; install_ruwall ;;
    services)   install_services ;;
    firefox)    install_firefox ;;
    lists)      regenerate_lists ;;
    *)
        [[ "$(id -u)" -eq 0 ]] && err "Não rode como root (o AUR exige usuário normal)."
        check_build_deps
        install_pacman
        install_aur
        install_firefox
        log "Sugestão: habilite os serviços com ./install.sh --services"
        log "Concluído. Reinicie para finalizar a configuração, se necessário."
        ;;
esac
