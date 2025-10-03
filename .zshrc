# =========================================
# Shell Configuration
# =========================================
# Enable vim mode for command line editing
bindkey -v

# =========================================
# History Configuration
# =========================================
HISTSIZE=10000
SAVEHIST=10000
HISTFILE=~/.zsh_history
setopt HIST_VERIFY
setopt SHARE_HISTORY
setopt APPEND_HISTORY
setopt INC_APPEND_HISTORY
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_REDUCE_BLANKS

# =========================================
# Auto Complete Configuration
# =========================================
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
# Add Neovim Mason binaries to PATH
export PATH="$HOME/.local/share/nvim/mason/bin:$PATH"

# Add Homebrew to PATH
export PATH="/opt/homebrew/bin:$PATH"

# Set Homebrew prefix for Apple Silicon Macs
export HOMEBREW_PREFIX="/opt/homebrew"

export EDITOR=neovim

# =========================================
# Node.js (NVM) Configuration
# =========================================
export NVM_DIR="$HOME/.nvm"
# Lazy load nvm for faster shell startup
nvm() {
    unset -f nvm
    [ -s "$HOMEBREW_PREFIX/opt/nvm/nvm.sh" ] && \. "$HOMEBREW_PREFIX/opt/nvm/nvm.sh"
    [ -s "$HOMEBREW_PREFIX/opt/nvm/etc/bash_completion.d/nvm" ] && \. "$HOMEBREW_PREFIX/opt/nvm/etc/bash_completion.d/nvm"
    nvm "$@"
}

# =========================================
# .NET Development Environment Variables
# =========================================
# Database connection (can be overridden by environment-specific config)
export DOTNET_ConnectionStrings__Database="${DOTNET_ConnectionStrings__Database:-Data Source=localhost,1433;Database=intl-depot-db;Integrated Security=false;User ID=SA;Password=Intl@depot1;TrustServerCertificate=True;}"
export DOTNET_MessagingOptions__Namespace="${DOTNET_MessagingOptions__Namespace:-amqp://guest:guest@localhost:5672/}"

# =========================================
# Angular Development Environment Variables
# =========================================
export CI=true
export KARMA_LOG_LEVEL="ERROR"
export NG_CLI_ANALYTICS=false

# =========================================
# Tool Integrations
# =========================================
# Set up fzf key bindings and fuzzy completion (check if fzf exists first)
if command -v fzf >/dev/null 2>&1; then
    source <(fzf --zsh)
fi

# =========================================
# Certs
# =========================================
export NODE_EXTRA_CA_CERTS=/Users/jlazarus/costco-certs.pem
export SSL_CERT_FILE=/Users/jlazarus/costco-certs.pem

# =========================================
# Aliases
# =========================================
# Enhanced ls with details and formatting (fallback to ls if eza not available)
if command -v eza >/dev/null 2>&1; then
    alias ls='eza --icons'
    alias l='eza -la --icons'
    alias ll='eza -la --icons'
    alias lt='eza -la --sort=modified --icons'
    alias tree='eza --tree --icons'
else
    alias l='ls -la'
    alias ll='ls -la'
    alias lt='ls -lat'
fi

# FZF with preview functionality
alias ff="fzf --style full --preview 'fzf-preview.sh {}'"
alias ..='cd ..'

alias code="code-insiders"
alias stoptanium='sudo launchctl unload /Library/LaunchDaemons/com.tanium.taniumclient.plist'

# =========================================
# Prompt Configuration
# =========================================
# Set prompt to [user :: cwd] with username in gitmux green (#9ece6a)
PROMPT='[ %F{#9ece6a}%n%f :: %~ ] '

# opencode
export PATH=/Users/jlazarus/.opencode/bin:$PATH

# bun completions
[ -s "/Users/jlazarus/.bun/_bun" ] && source "/Users/jlazarus/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
