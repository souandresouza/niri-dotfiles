# niri-dotfiles

Configuração do compositor Wayland **niri** e scripts de apoio (wal, wallpapers,
notificações, etc.), sincronizados em um repositório git.

## Estrutura

```
niri-dotfiles/
├── install.sh              # Instala pacotes das listas (official + AUR)
├── link.sh                 # Cria symlinks de .config/niri e .config/scripts
├── check.sh                # Valida sintaxe dos scripts (.sh)
├── lista_pacman.txt        # Pacotes oficiais explícitos (pacman -Qenq)
├── lista_aur.txt           # Pacotes do AUR explícitos (pacman -Qemq)
├── servicos.txt            # Serviços systemd a habilitar
└── .config/
    ├── niri/               # Config do niri (config, binds, layout, animações)
    └── scripts/            # Scripts usados pelos binds e atalhos
```

## Restauração em uma máquina nova

Pré-requisitos: Arch Linux base instalado, usuário criado e `sudo` configurado.

```sh
# 1. Clone e instale os pacotes (primeira execução como usuário comum)
git clone <url-do-repo> ~/niri-dotfiles
cd ~/niri-dotfiles
./install.sh              # instala todos os pacotes (oficial + AUR)
./install.sh --services   # habilita serviços de servicos.txt (bluetooth, NM, etc.)

# 2. Deploy das configurações por symlink (backup automático dos diretórios existentes)
./link.sh

# 3. Dependência local: ruwall (binário, não é pacote)
#    Baixe o binário do ruwall e coloque em $HOME/.local/bin/ruwall
#    (usado pelo random-wallpaper.sh)
```

> Serviços específicos da máquina (ex.: `seatd.service`, `ollama.service`) podem
> ser removidos de `servicos.txt` se não fizerem sentido no destino.

Depois da instalação:

```sh
# Wallpaper inicial (gera o tema wal) e regeneração dos esquemas de cor
ruwall -i "$HOME/.config/wallpapers/algum_wallpaper.png"
~/.config/scripts/run-scripts.sh    # gera cores para niri, waybar, etc.
```

## Atualizando as listas de pacotes

Quando instalar/remover pacotes explicitamente, regenere as listas e commite:

```sh
./install.sh --update-lists     # regenera lista_pacman.txt e lista_aur.txt
git add lista_*.txt && git commit -s -m "Atualizar lista de pacotes"
```

## Validação

```sh
./check.sh               # sh -n / bash -n em todos os scripts
./check.sh --shellcheck  # também roda shellcheck (se instalado)
```

## Notas

- **`layout.kdl`** é gerado a partir das cores do wal pelo
  `scripts/colors/niri-colors.sh` (executado via `run-scripts.sh` no startup e no
  `Mod+G`). A versão versionada serve de fallback para máquinas novas antes do
  primeiro `ruwall`; depois ela é sobrescrita com as cores do wallpaper atual.
- **Configurações de outros apps** (waybar, fuzzel, kitty, swaync, cava, etc.)
  **não são versionadas**: as partes dinâmicas são geradas pelos scripts de cor
  em `scripts/colors/` (ex.: `colors-waybar.css`), que regeneram os esquemas a
  partir do wal. O repositório guarda apenas os scripts que as geram, não a
  saída.
- Depois de rodar `./link.sh`, os diretórios em `$HOME/.config` apontam para o
  repositório: edite os arquivos **dentro do repo** e commite.