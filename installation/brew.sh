#!/bin/bash

# =========================================
# Homebrew Installation Script
# =========================================
# Run this script to install all Homebrew packages and applications
# Usage: chmod +x brew.sh && ./brew.sh

set -e

echo "🍺 Installing Homebrew packages..."

# =========================================
# Core Development Tools
# =========================================
brew install git
brew install gh
brew install neovim
brew install tmux
brew install fzf
brew install ripgrep
brew install fd
brew install eza
brew install bat
brew install tree
brew install jq
brew install wget
brew install lazygit
brew install gitmux
brew install --cask visual-studio-code

# =========================================
# Shell & Terminal Enhancements
# =========================================
brew install powerlevel10k
brew install zsh
brew install bash
brew install coreutils
brew install gnu-sed
brew install gnu-tar
brew install grep
brew install gawk
brew install --cask ghostty

# =========================================
# Programming Languages & Runtimes
# =========================================
brew install pnpm
brew install nvm
brew install python@3.13
brew install lua
brew install luajit
brew install marksman #markdown lsp
brew install --cask dotnet-sdk
brew install --cask dotnet-sdk8-0-200

# =========================================
# Azure & Cloud Tools
# =========================================
brew install azure-cli
brew install azure-functions-core-tools@4
brew install terraform

# =========================================
# System Utilities
# =========================================
brew install xh
brew install switchaudio-osx
brew install nowplaying-cli
brew install sketchybar

# =========================================
# Image & Media Processing
# =========================================
brew install imagemagick
brew install graphviz

# =========================================
# Build Tools & Libraries
# =========================================
brew install cmake
brew install make
brew install gcc
brew install autoconf
brew install pkgconf
brew install libtool

# =========================================
# Fonts
# =========================================
brew install --cask font-0xproto
brew install --cask font-0xproto-nerd-font
brew install --cask font-fantasque-sans-mono
brew install --cask font-fira-code-nerd-font
brew install --cask font-hack-nerd-font
brew install --cask font-jetbrains-mono-nerd-font
brew install --cask font-monaspace-nerd-font
brew install --cask font-noto-sans
brew install --cask font-sf-mono
brew install --cask font-sf-pro
brew install --cask sf-symbols

# =========================================
# Applications
# =========================================
brew install --cask spotify

echo "✅ All Homebrew packages installed successfully!"
echo "🔧 Don't forget to run 'source ~/.zshrc' to reload your shell configuration"
