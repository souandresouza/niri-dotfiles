#!/usr/bin/env bash
# =============================================================================
# link.sh -- cria symlinks do repositório para $HOME/.config
# =============================================================================
#
# Uso:
#   ./link.sh            Linka $HOME/.config/niri e $HOME/.config/scripts
#   ./link.sh --dry-run  Mostra o que seria feito, sem alterar nada
#   ./link.sh --help     Ajuda
#
# Diretórios reais existentes em $HOME/.config são movidos para um backup
# (sufixo .bak-<timestamp>) antes de criar o symlink.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$HOME/.config"

DRY_RUN=0
TARGETS=(niri scripts)

log() { printf '[link.sh] %s\n' "$*"; }
err() { printf '[link.sh] ERRO: %s\n' "$*" >&2; exit 1; }

link_target() {
    local name="$1"
    local src="$REPO_DIR/.config/$name"
    local dst="$CONFIG_DIR/$name"

    [[ -d "$src" ]] || { log "Origem não encontrada, ignorando: $src"; return; }

    if [[ -L "$dst" ]]; then
        if [[ "$(readlink -f "$dst")" == "$(readlink -f "$src")" ]]; then
            log "Já linkado: $dst -> $src"
        else
            err "$dst é um symlink para outro destino"
        fi
        return
    fi

    if [[ -e "$dst" ]]; then
        local bak="$dst.bak-$(date +%Y%m%d-%H%M%S)"
        if [[ "$DRY_RUN" -eq 1 ]]; then
            log "Faria backup: $dst -> $bak"
        else
            log "Backup de $dst em $bak"
            mv "$dst" "$bak"
        fi
    fi

    if [[ "$DRY_RUN" -eq 1 ]]; then
        log "Criaria symlink: $dst -> $src"
    else
        ln -s "$src" "$dst"
        log "Symlink criado: $dst -> $src"
    fi
}

while (($#)); do
    case "$1" in
        --dry-run) DRY_RUN=1 ;;
        --help|-h)
            sed -n '2,8p' "${BASH_SOURCE[0]}" | sed 's/^#//'
            exit 0
            ;;
        *) err "Opção desconhecida: $1 (use --help)" ;;
    esac
    shift
done

for target in "${TARGETS[@]}"; do
    link_target "$target"
done

log "Concluído. As regras passam a valer nos arquivos do repositório."