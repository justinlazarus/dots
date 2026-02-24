# =========================================
# Shell Configuration
# =========================================
bindkey -v

# =========================================
# OS Detection
# =========================================
case "$(uname -s)" in
    Darwin) IS_MAC=true ;;
    Linux)  IS_LINUX=true ;;
esac

# =========================================
# Linux-specific Configuration
# =========================================
if [[ $IS_LINUX ]]; then
    export WLR_NO_HARDWARE_CURSORS=1
fi

# =========================================
# History Configuration
# =========================================
HISTSIZE=10000
SAVEHIST=10000
HISTFILE=~/.zsh_history
setopt HIST_VERIFY
setopt SHARE_HISTORY
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_REDUCE_BLANKS

# =========================================
# Auto Complete Configuration
# =========================================
[[ -d "$HOME/.docker/completions" ]] && fpath=($HOME/.docker/completions $fpath)
autoload -Uz compinit && compinit
setopt AUTO_MENU
setopt COMPLETE_IN_WORD
setopt ALWAYS_TO_END
setopt AUTO_CD
setopt AUTO_PUSHD
setopt PUSHD_IGNORE_DUPS

# =========================================
# PATH Configuration
# =========================================
if [[ $IS_MAC ]]; then
    export HOMEBREW_PREFIX="/opt/homebrew"
    export PATH="$HOMEBREW_PREFIX/bin:$PATH"
fi

export PATH="$HOME/.local/bin:$HOME/dots/utils:$HOME/.local/share/nvim/mason/bin:$PATH"
export PATH="$HOME/.local/share/bob/nvim-bin:$PATH"
export PATH="$HOME/.cargo/bin:$PATH"
export PATH="$HOME/go/bin:$PATH"
export PATH="$HOME/.opencode/bin:$PATH"

export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# =========================================
# SSL/TLS Certificates
# =========================================
if [[ $IS_MAC ]]; then
    mkdir -p ~/.certs
    security find-certificate -a -p \
        /System/Library/Keychains/SystemRootCertificates.keychain \
        /Library/Keychains/System.keychain \
        > ~/.certs/ca-bundle.crt 2>/dev/null
    export SSL_CERT_FILE="$HOME/.certs/ca-bundle.crt"
    export REQUESTS_CA_BUNDLE="$SSL_CERT_FILE"
    export NODE_EXTRA_CA_CERTS="$SSL_CERT_FILE"
fi

# =========================================
# Environment Variables
# =========================================
unset CI
export EDITOR=nvim
export COLORTERM=truecolor
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
export OLLAMA_FLASH_ATTENTION=1
export OLLAMA_HOST=100.79.200.80

# =========================================
# Node.js (NVM) - Lazy Loaded
# =========================================
export NVM_DIR="$HOME/.nvm"
nvm() {
    unset -f nvm
    if [[ $IS_MAC ]]; then
        [ -s "$HOMEBREW_PREFIX/opt/nvm/nvm.sh" ] && \. "$HOMEBREW_PREFIX/opt/nvm/nvm.sh"
        [ -s "$HOMEBREW_PREFIX/opt/nvm/etc/bash_completion.d/nvm" ] && \. "$HOMEBREW_PREFIX/opt/nvm/etc/bash_completion.d/nvm"
    else
        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
        [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
    fi
    nvm "$@"
}

# =========================================
# Angular Development Environment Variables
# =========================================
export KARMA_LOG_LEVEL="ERROR"
export NG_CLI_ANALYTICS=false

# =========================================
# Tool Integrations
# =========================================
if command -v fzf >/dev/null 2>&1; then
    source <(fzf --zsh)
fi

[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"

command -v ng >/dev/null 2>&1 && source <(ng completion script)

# =========================================
# Aliases
# =========================================
if command -v eza >/dev/null 2>&1; then
    alias ls='eza --icons'
    alias l='eza -la --icons'
    alias ll='eza -la --icons'
    alias tree='eza --tree --icons'
else
    alias l='ls -la'
    alias ll='ls -la'
fi

alias ff="fzf --style full --preview 'fzf-preview.sh {}'"
alias ..='cd ..'

if [[ $IS_MAC ]]; then
    alias stoptanium='sudo launchctl unload /Library/LaunchDaemons/com.tanium.taniumclient.plist'
fi
alias chobster-dash='~/chobster/venv/bin/python ~/chobster/dashboard.py'

# Fix stale code-insiders alias (VS Code regular, not Insiders)
unalias code 2>/dev/null

# =========================================
# Prompt Configuration
# =========================================
PROMPT='[ %F{#9ece6a}%n%f :: %~ ] '

# =========================================
# Local overrides (machine-specific secrets, etc.)
# =========================================
[[ -f ~/.zshrc.local ]] && source ~/.zshrc.local
