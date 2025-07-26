# =============================================================================
# ZSH CONFIGURATION
# =============================================================================

# -----------------------------------------------------------------------------
# Powerlevel10k Instant Prompt (must be at top)
# -----------------------------------------------------------------------------
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

source /usr/share/zsh-theme-powerlevel10k/powerlevel10k.zsh-theme

# -----------------------------------------------------------------------------
# History Configuration
# -----------------------------------------------------------------------------
HISTFILE=~/.histfile
HISTSIZE=1000
SAVEHIST=1000

# -----------------------------------------------------------------------------
# Shell Options
# -----------------------------------------------------------------------------
setopt extendedglob    # Advanced pattern matching
unsetopt beep         # Disable system beeps

# -----------------------------------------------------------------------------
# Key Bindings
# -----------------------------------------------------------------------------
bindkey -v            # Use vi/vim keybindings

# -----------------------------------------------------------------------------
# Completion System
# -----------------------------------------------------------------------------
zstyle :compinstall filename '/home/djlaz/.zshrc'
autoload -Uz compinit
compinit

# -----------------------------------------------------------------------------
# Environment Variables
# -----------------------------------------------------------------------------
# XDG Base Directory Specification
export XDG_RUNTIME_DIR="/run/user/$(id -u)"
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_CACHE_HOME="$HOME/.cache"

# Wayland/Graphics
export XDG_SESSION_TYPE=wayland
export LIBVA_DRIVER_NAME=nvidia
export GBM_BACKEND=nvidia-drm
export __GLX_VENDOR_LIBRARY_NAME=nvidia

# Application Paths
export PATH="$HOME/.local/share/nvim/mason/bin:$PATH"

# Docker
export DOCKER_HOST=unix:///var/run/docker.sock

# -----------------------------------------------------------------------------
# Package Management Aliases
# -----------------------------------------------------------------------------
alias pacup='sudo pacman -Syu'
alias pacsearch='pacman -Ss'
alias pacinstall='sudo pacman -S'
alias yayup='yay -Syu'

# -----------------------------------------------------------------------------
# System/Shell Aliases
# -----------------------------------------------------------------------------
alias ls='ls --color=auto'
alias ll='ls -alF'
alias grep='grep --color=auto'

# -----------------------------------------------------------------------------
# Application Aliases
# -----------------------------------------------------------------------------
alias hyprconfig='nvim ~/.config/hypr/hyprland.conf'
alias ff="fzf --style full --preview 'fzf-preview.sh {}'"

# -----------------------------------------------------------------------------
# Plugin/Tool Setup
# -----------------------------------------------------------------------------
# FZF key bindings and fuzzy completion
source <(fzf --zsh)

# Powerlevel10k configuration
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
