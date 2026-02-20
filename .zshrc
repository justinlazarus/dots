# =========================================
# Shell Configuration
# =========================================
bindkey -v

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
fpath=($HOME/.docker/completions $fpath)
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
export HOMEBREW_PREFIX="/opt/homebrew"
export PATH="$HOME/.local/bin:$HOME/dots/utils:$HOME/.local/share/nvim/mason/bin:$PATH"
export PATH="$HOMEBREW_PREFIX/bin:$PATH"
export PATH="$HOME/.cargo/bin:$PATH"
export PATH="$HOME/go/bin:$PATH"
export PATH="$HOME/.opencode/bin:$PATH"
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# =========================================
# Environment Variables
# =========================================
unset CI
export EDITOR=nvim
export COLORTERM=truecolor
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

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
export CWIMS_ADMIN_PASSWORD="Costco123@"
export Database__DepotDbConnectionString="Server=localhost,1433;Database=depot-db;User Id=sa;Password=Costco12345@;TrustServerCertificate=true;Encrypt=false;"
export Database__ReadOnlyDepotDbConnectionString="Server=localhost,1433;Database=depot-db;User Id=sa;Password=Costco12345@;TrustServerCertificate=true;Encrypt=false;"
export DOTNET_ConnectionStrings__Database="${DOTNET_ConnectionStrings__Database:-Data Source=localhost,1433;Database=intl-depot-db;Integrated Security=false;User ID=SA;Password=Intl@depot1;TrustServerCertificate=True;}"
export DOTNET_MessagingOptions__Namespace="${DOTNET_MessagingOptions__Namespace:-amqp://guest:guest@localhost:5672/}"
export OTEL_EXPORTER_OTLP_ENDPOINT="http://localhost:4317"
export OTEL_SERVICE_NAME="Depot"
export ASPNETCORE_ENVIRONMENT=Development

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

# Bun completions
[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"

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
alias code="code-insiders"
alias stoptanium='sudo launchctl unload /Library/LaunchDaemons/com.tanium.taniumclient.plist'
alias chobster-dash='~/chobster/venv/bin/python ~/chobster/dashboard.py'

# =========================================
# Prompt Configuration
# =========================================
PROMPT='[ %F{#9ece6a}%n%f :: %~ ] '

# opencode
export PATH=/Users/jlazarus/.opencode/bin:$PATH

# bun completions
[ -s "/Users/jlazarus/.bun/_bun" ] && source "/Users/jlazarus/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# The following lines have been added by Docker Desktop to enable Docker CLI completions.
fpath=(/Users/jlazarus/.docker/completions $fpath)
autoload -Uz compinit
compinit
# End of Docker CLI completions
#


# =========================================
# Prompt Configuration
# =========================================

export WLR_NO_HARDWARE_CURSORS=1
export OLLAMA_FLASH_ATTENTION=1
export OLLAMA_HOST=100.79.200.80
export PATH="$HOME/.local/share/bob/nvim-bin:$HOME/.local/bin:$PATH"
=======
>>>>>>> e35fc5afbbb1251e7d61e1065d6a4a0ad50a5021
