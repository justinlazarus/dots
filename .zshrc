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
    
    # Append Costco proxy certificate chains in proper order for Go TLS validation
    # Cached to avoid slow network calls on every shell startup
    CHAIN_CACHE="$HOME/.certs/costco-proxy-chain.pem"
    if [[ ! -f "$CHAIN_CACHE" ]] || [[ $(find "$CHAIN_CACHE" -mtime +1 2>/dev/null) ]]; then
        # Cache is missing or older than 1 day, try to refresh from network
        for host in nodejs.org github.com npmjs.com; do
            if timeout 2 bash -c "</dev/tcp/$host/443" 2>/dev/null; then
                openssl s_client -connect $host:443 -showcerts </dev/null 2>&1 | \
                    sed -n '/BEGIN CERTIFICATE/,/END CERTIFICATE/p' > "$CHAIN_CACHE" 2>/dev/null && break
            fi
        done
    fi
    # Append cached chain if it exists
    # To manually refresh: rm ~/.certs/costco-proxy-chain.pem && source ~/.zshrc
    [[ -f "$CHAIN_CACHE" ]] && cat "$CHAIN_CACHE" >> ~/.certs/ca-bundle.crt 2>/dev/null
    
    export SSL_CERT_FILE="$HOME/.certs/ca-bundle.crt"
    export REQUESTS_CA_BUNDLE="$SSL_CERT_FILE"
    export NODE_EXTRA_CA_CERTS="$SSL_CERT_FILE"

    # Background sync: update macOS System keychain with corporate CA certs
    # Start the helper without printing job control lines. Prefer zsh's &!
    # which starts and immediately disowns the job; fall back to setsid if
    # &! is not supported in the current shell.
    if [[ -x "$HOME/dots/utils/update-keychain.sh" ]]; then
        if [[ -o interactive && ${ZSH_VERSION-} ]]; then
            # zsh: use &! to avoid the "[3] 21102" job line
            "$HOME/dots/utils/update-keychain.sh" >/dev/null 2>&1 &!
        elif command -v setsid >/dev/null 2>&1; then
            setsid "$HOME/dots/utils/update-keychain.sh" >/dev/null 2>&1 &
        else
            nohup "$HOME/dots/utils/update-keychain.sh" >/dev/null 2>&1 & disown
        fi
    fi
fi

# =========================================
# Environment Variables
# =========================================
unset CI
export DOTNET_CLI_TELEMETRY_OPTOUT=1
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
alias sshghostty='ghostty --class=com.mitchellh.ghostty.ssh'

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

if command -v wt >/dev/null 2>&1; then
    eval "$(command wt config shell init zsh)"
    alias wts='wt switch --no-cd'
fi
alias lg='lazygit'
