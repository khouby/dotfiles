#                                   _
#                              ____ | |__   ___ _ __ ___
#                             |_  / | '_ \ / __| '__/ __|
#                              / /  | | | | (__| | | (__
#                             /___| |_| |_|\___|_|  \___|
#
# Sections:
#   1. Plugin manager (Znap)  4. Shell options       7. Aliases
#   2. Completions / fpath    5. Keybindings         8. Tool init (eval)
#   3. Plugins                6. Functions           9. Environment / PATH

# ──────────────────────────────────────────────────────────────────────────
# 1. Plugin manager (Znap)
# ──────────────────────────────────────────────────────────────────────────
# Bootstrap Znap on first run, then source it.
[[ -r ~/.zsh/znap/znap.zsh ]] || git clone --depth 1 -- https://github.com/marlonrichert/zsh-snap.git ~/.zsh/znap
source ~/.zsh/znap/znap.zsh

mkdir -p ~/.zsh/znap/repos                          # where Znap clones plugins
zstyle ':znap:*' repos-dir ~/.zsh/znap/repos

# ──────────────────────────────────────────────────────────────────────────
# 2. Completions / fpath  (must come before compinit)
# ──────────────────────────────────────────────────────────────────────────
fpath=(~/.docker/completions $fpath)
fpath+=("/opt/homebrew/share/zsh/site-functions")
fpath+=("$HOME/.zsh/completions")

autoload -Uz compinit
znap eval _compinit "compinit -d ~/.zcompdump"      # cache compinit for faster startup

# ──────────────────────────────────────────────────────────────────────────
# 3. Plugins
# ──────────────────────────────────────────────────────────────────────────
# Order matters: autosuggestions before syntax-highlighting; syntax-highlighting
# must be sourced after every plugin that defines ZLE widgets; and
# history-substring-search must come *after* syntax-highlighting.
znap source zsh-users/zsh-completions
znap source zsh-users/zsh-autosuggestions
znap source changyuheng/zsh-interactive-cd
znap source wfxr/forgit
znap source Aloxaf/fzf-tab
znap source g-plane/zsh-yarn-autocompletions
znap source zsh-users/zsh-syntax-highlighting       # keep last of the widget plugins
znap source zsh-users/zsh-history-substring-search  # after syntax-highlighting

# ──────────────────────────────────────────────────────────────────────────
# 4. Shell options
# ──────────────────────────────────────────────────────────────────────────
# History
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt SHARE_HISTORY          # share history across running sessions
setopt EXTENDED_HISTORY       # record timestamp + duration per command
setopt HIST_IGNORE_DUPS       # don't record an entry that matches the previous one
setopt HIST_IGNORE_SPACE      # don't record commands prefixed with a space
setopt HIST_REDUCE_BLANKS     # trim superfluous whitespace before saving
setopt HIST_FIND_NO_DUPS      # don't show duplicates when searching history
setopt HIST_SAVE_NO_DUPS      # don't write duplicate entries to the history file

# Behavior
setopt AUTO_CD                # `cd` by typing a directory name
setopt CORRECT                # offer spell correction for commands
setopt INTERACTIVE_COMMENTS   # allow `#` comments in the interactive shell

# ──────────────────────────────────────────────────────────────────────────
# 5. Keybindings
# ──────────────────────────────────────────────────────────────────────────
# Up/Down search history by the prefix already typed (both terminal modes).
bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down
bindkey '^[OA' history-substring-search-up
bindkey '^[OB' history-substring-search-down

# ──────────────────────────────────────────────────────────────────────────
# 6. Functions
# ──────────────────────────────────────────────────────────────────────────
# --- Docker / project helpers ---
_COMPOSE_FILE=docker-compose-arm.yml

# Resolve the running "app" container name (empty if not up).
_docker_app_container() {
  docker compose -f "$_COMPOSE_FILE" ps -q app 2>/dev/null \
    | xargs docker inspect --format='{{.Name}}' 2>/dev/null \
    | sed 's/\///'
}

# Echo the running app container name, or print an error and return non-zero.
_require_app_container() {
  [[ -f "$_COMPOSE_FILE" ]] || { echo "no $_COMPOSE_FILE in $PWD" >&2; return 1; }
  local name=$(_docker_app_container)
  [[ -n "$name" ]] || { echo "container 'app' is not running ($_COMPOSE_FILE)" >&2; return 1; }
  print -r -- "$name"
}

# Run a binary in the app container, or fall back to the host binary if the
# container isn't up. Usage: _docker_or_host "<exec-flags>" <binary> [args...]
_docker_or_host() {
  local flags=$1 bin=$2; shift 2
  local name; name=$(_require_app_container 2>/dev/null) \
    && { docker exec ${=flags} "$name" "$bin" "$@"; return; }
  echo "Using host $bin" >&2
  command "$bin" "$@"
}

# `container "php artisan migrate"` — run a command string in the app container.
container()    { local n; n=$(_require_app_container) && docker exec "$n" bash -c "$*"; }
# Interactive bash shell in the app container.
container_it() { local n; n=$(_require_app_container) && docker exec -it "$n" bash; }

run_php_in_docker()      { _docker_or_host "-it" php "$@"; }
run_composer_in_docker() { _docker_or_host "-e COMPOSER_MEMORY_LIMIT=-1" composer "$@"; }

# Stop every running container.
dstop() {
  local containers=$(docker ps -q)
  [[ -n "$containers" ]] && docker stop ${=containers} || echo "No running containers"
}

# Wait briefly if the Docker daemon isn't ready, then bring the stack up.
_docker_wait() { docker system info &>/dev/null || { echo "Waiting for Docker..."; sleep 2; }; }
dcu()  { _docker_wait; docker compose -f docker-compose-arm.yml up -d "$@"; }
dcud() { _docker_wait; docker compose -f docker-compose-arm-dual.yml up -d "$@"; }

# ──────────────────────────────────────────────────────────────────────────
# 7. Aliases
# ──────────────────────────────────────────────────────────────────────────
# React Native
alias rn="npx react-native"
alias rn-run="npx react-native run-ios --no-packager"
alias rn-start="npx react-native start --reset-cache"

# Docker
alias dcd="docker compose -f docker-compose-arm.yml down"
alias dcad="dstop"            # stop all running containers
alias dcp="docker ps"
alias dcr="dcd && dcu"        # restart the stack
alias gi="lazygit"
alias di="lazydocker"
alias dotfiles='git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME'

# Project / dev
alias tunnel="ngrok http --host-header=rewrite 443"
alias php="run_php_in_docker"
alias composer="run_composer_in_docker"
alias editor="phpstorm ."

# Modern CLI replacements
alias neofetch="fastfetch"
alias man="tldr"
alias dir="spf"
alias vim="nvim"
alias ls="eza --icons=always"
alias ll="eza -la --icons=always"
alias la="eza -a --icons=always"
alias tree="eza --tree --icons=always"

# Safety nets (prompt before clobbering)
alias rm="rm -i"
alias mv="mv -i"
alias cp="cp -i"

# Navigation shortcuts
alias c="clear"
alias ..="cd .."
alias ...="cd ../.."

# ──────────────────────────────────────────────────────────────────────────
# 8. Tool initialization
# ──────────────────────────────────────────────────────────────────────────
eval "$(starship init zsh)"
eval "$(zoxide init zsh --cmd cd)"   # zoxide provides `cd` (jump) and `cdi` (pick)
eval "$(thefuck --alias FUCK)"
eval "$(fnm env --use-on-cd --shell zsh)"

# Lazy-load pyenv (init is slow; defer it until first use).
pyenv() {
  unfunction pyenv
  eval "$(command pyenv init - zsh)"
  pyenv "$@"
}

# ──────────────────────────────────────────────────────────────────────────
# 9. Environment / PATH
# ──────────────────────────────────────────────────────────────────────────
# pyenv
export PYENV_ROOT="$HOME/.pyenv"
[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"

# Android SDK
export ANDROID_HOME=$HOME/Library/Android/sdk
export PATH=$PATH:$ANDROID_HOME/emulator
export PATH=$PATH:$ANDROID_HOME/platform-tools

# opencode
export PATH="$HOME/.opencode/bin:$PATH"

# Docker
export COMPOSE_IGNORE_ORPHANS=1

# fzf
export FZF_DEFAULT_OPTS="
  --height 80%
  --layout=reverse
  --border=rounded
  --preview-window=right:60%:wrap
  --bind 'ctrl-/:toggle-preview'
  --preview '
    if [ -d {} ]; then
      eza --tree --color=always {} | head -200
    else
      bat --color=always --style=numbers --line-range=:500 {}
    fi
  '
"

# Local binaries
export PATH="$HOME/.local/bin:$PATH"
