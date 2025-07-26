# =========================================
# Powerlevel10k Instant Prompt
# =========================================
# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# =========================================
# Shell Configuration
# =========================================
# Enable vim mode for command line editing
bindkey -v

# =========================================
# PATH Configuration
# =========================================
# Add Neovim Mason binaries to PATH
export PATH="$HOME/.local/share/nvim/mason/bin:$PATH"

# Add Homebrew to PATH
export PATH="/opt/homebrew/bin:$PATH"

# =========================================
# Node.js (NVM) Configuration
# =========================================
export NVM_DIR="$HOME/.nvm"
[ -s "$HOMEBREW_PREFIX/opt/nvm/nvm.sh" ] && \. "$HOMEBREW_PREFIX/opt/nvm/nvm.sh" # This loads nvm
[ -s "$HOMEBREW_PREFIX/opt/nvm/etc/bash_completion.d/nvm" ] && \. "$HOMEBREW_PREFIX/opt/nvm/etc/bash_completion.d/nvm" # This loads nvm bash_completion

# =========================================
# .NET Development Environment Variables
# =========================================
export DOTNET_ConnectionStrings__Database="Data Source=localhost,1433;Database=intl-depot-db;Integrated Security=false;User ID=SA;Password=Intl@depot1;TrustServerCertificate=True;"
export DOTNET_MessagingOptions__Namespace="amqp://guest:guest@localhost:5672/"

# =========================================
# Theme Configuration
# =========================================
# Load Powerlevel10k theme
source /opt/homebrew/share/powerlevel10k/powerlevel10k.zsh-theme

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# =========================================
# Tool Integrations
# =========================================
# Set up fzf key bindings and fuzzy completion
source <(fzf --zsh)

# =========================================
# Aliases
# =========================================
# Enhanced ls with details and formatting
alias ll='ls -alF'

# FZF with preview functionality
alias ff="fzf --style full --preview 'fzf-preview.sh {}'"
