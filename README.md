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

## cadrocfile (gerenciador de arquivos)

O [cadrocfile](https://github.com/souandresouza/cadrocfile) é o meu gerenciador de arquivos GTK4 + Libadwaita. 

Ele já está mapeado no `binds.kdl` com:

```kdl
Mod+E { spawn "cadrocfile"; }
```

### Instalação

O próprio repositório `cadrocfile` já tem um instalador bem completo (`install.sh`), que baixa binário pré-compilado quando possível ou compila a partir do código.

#### Opção 1: Pelo install.sh do niri-dotfiles (recomendado)

```sh
cd ~/niri-dotfiles
./install.sh --cadrocfile
```

Ele vai clonar/usar `~/cadrocfile`, rodar o instalador dele e colocar o binário em `~/.local/bin/` (ou `/usr/local/bin/` caso rode com privilégios necessários).

#### Opção 2: Manual

```sh
# Clonar (se ainda não tiver)
git clone https://github.com/souandresouza/cadrocfile ~/cadrocfile
cd ~/cadrocfile

# Instalar (detecta distro, instala deps, baixa binário ou compila)
./install.sh
```

### Configuração

As configurações ficam em `~/.config/cadrocfile/`. O instalador **não** sobrescreve nada que já exista lá.

### Dica

Garanta que `~/.local/bin` está no seu `$PATH`. Em muitas distros já vem, mas caso não venha, adicione ao seu `.bashrc`/`.zshrc`:

```sh
export PATH="$HOME/.local/bin:$PATH"
```


## ruwall (gerador de paleta de cores)

O [ruwall](https://github.com/souandresouza/ruwall) é um port em Rust do `pywal`. Ele gera uma paleta de cores a partir do wallpaper e aplica em vários aplicativos (waybar, kitty, fuzzel, niri etc.).

É usado pelos scripts do repositório, principalmente pelo `random-wallpaper.sh`, para manter o tema dinâmico conforme o wallpaper.

### Instalação

#### Opção 1: Pelo install.sh do niri-dotfiles (recomendado)

```sh
cd ~/niri-dotfiles
./install.sh --ruwall
```

Ele vai clonar/usar `~/ruwall`, compilar com `cargo build --release` e instalar o binário em `~/.local/bin/ruwall`.

#### Opção 2: Manual

```sh
# Clonar (se ainda não tiver)
git clone https://github.com/souandresouza/ruwall ~/ruwall
cd ~/ruwall

# Compilar e instalar
cargo build --release
install -m755 target/release/ruwall ~/.local/bin/ruwall
```

### Requisitos

- `rustup` / toolchain Rust funcional
- `base-devel` (ou `build-essential`) já vem nas listas do `install.sh`

### Uso básico

```sh
# Gerar cores a partir de um wallpaper
ruwall -i ~/Imagens/wallpapers/meu-wallpaper.jpg

# Restaurar último esquema
ruwall -R

# Usar tema pré-definido
ruwall -f base16-monokai
```

> Os caches ficam em `~/.cache/wal/` (`colors.json`, `colors.sh`, etc), no mesmo padrão do pywal.
