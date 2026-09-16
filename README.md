# niri-dotfiles

Configuração do compositor Wayland **niri** e scripts de apoio (wal, wallapapers,
notificações, etc.), sincronizados em um repositório git.

## Estrutura

```
niri-dotfiles/
├── install.sh              # Instala pacotes das listas (official + AUR)
├── link.sh                 # Cria symlinks de .config/niri e .config/scripts
├── lista_pacman.txt        # Pacotes oficiais explícitos (pacman -Qenq)
├── lista_aur.txt           # Pacotes do AUR explícitos (pacman -Qemq)
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

# 2. Deploy das configurações por symlink (backup automático dos diretórios existentes)
./link.sh

# 3. Dependência local: ruwall (binário, não é pacote)
#    Baixe o binário do ruwall e coloque em $HOME/.local/bin/ruwall
#    (usado pelo random-wallpaper.sh)
```

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

## Notas

- **`layout.kdl`** é gerado a partir das cores do wal pelo
  `scripts/colors/niri-colors.sh` (executado via `run-scripts.sh` no startup e no
  `Mod+G`). A versão versionada serve de fallback para máquinas novas antes do
  primeiro `ruwall`; depois ela é sobrescrita com as cores do wallpaper atual.
- Depois de rodar `./link.sh`, os diretórios em `$HOME/.config` apontam para o
  repositório: edite os arquivos **dentro do repo** e commite.