#!/bin/zsh

# =========================================
# macOS Setup and Configuration Script
# =========================================
# Installs Homebrew packages and configures macOS settings for optimal development workflow
# Usage: chmod +x install.sh && ./install.sh

set -e

echo "🚀 Starting macOS setup..."

# =========================================
# Package Installation
# =========================================
echo "📦 Installing Homebrew packages..."
./brew.sh

# =========================================
# Dock Configuration
# =========================================
echo "🏠 Configuring Dock..."

# Auto-hide dock with no delay for clean desktop
defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock autohide-delay -float 0
defaults write com.apple.dock autohide-time-modifier -int 0

# Visual improvements
defaults write com.apple.dock persistent-apps -array-add '{tile-data={}; tile-type="spacer-tile";}'  # Add spacer
defaults write com.apple.dock showhidden -bool true  # Translucent hidden app icons

# Mission Control integration
defaults write com.apple.dock mru-spaces -bool false  # Keep spaces in consistent order

killall Dock

# =========================================
# Mission Control & Spaces
# =========================================
echo "🎛️  Configuring Mission Control..."

# Enable Option+1,2,3,4 for direct space switching (compatible with yabai/sketchybar)
defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 118 "<dict><key>enabled</key><true/><key>value</key><dict><key>parameters</key><array><integer>49</integer><integer>18</integer><integer>262144</integer></array><key>type</key><string>standard</string></dict></dict>"
defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 119 "<dict><key>enabled</key><true/><key>value</key><dict><key>parameters</key><array><integer>50</integer><integer>19</integer><integer>262144</integer></array><key>type</key><string>standard</string></dict></dict>"
defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 120 "<dict><key>enabled</key><true/><key>value</key><dict><key>parameters</key><array><integer>51</integer><integer>20</integer><integer>262144</integer></array><key>type</key><string>standard</string></dict></dict>"
defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 121 "<dict><key>enabled</key><true/><key>value</key><dict><key>parameters</key><array><integer>52</integer><integer>21</integer><integer>262144</integer></array><key>type</key><string>standard</string></dict></dict>"

# Note: Other Mission Control shortcuts are disabled for yabai/sketchybar compatibility

# =========================================
# Finder Configuration
# =========================================
echo "📁 Configuring Finder..."

# Visibility settings
defaults write NSGlobalDomain AppleShowAllExtensions -bool true  # Show file extensions
defaults write com.apple.finder AppleShowAllFiles -bool true     # Show hidden files
defaults write com.apple.finder _FXShowPosixPathInTitle -bool true  # POSIX path in title
defaults write com.apple.finder ShowPathbar -bool true           # Show path bar

# Organization and view settings
defaults write com.apple.finder _FXSortFoldersFirst -bool true   # Folders first when sorting
defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"  # List view by default
defaults write com.apple.finder DisableAllAnimations -bool true  # Disable animations for speed

killall Finder

# =========================================
# System-wide Settings
# =========================================
echo "⚙️  Configuring system settings..."

# Menu bar (hidden for sketchybar usage)
defaults write NSGlobalDomain _HIHideMenuBar -bool true

# Keyboard settings (commented out - adjust if needed)
# defaults write -g InitialKeyRepeat -int 15  # Initial repeat delay (225ms)
# defaults write -g KeyRepeat -int 1          # Key repeat rate (15ms)

# Screenshot settings
defaults write com.apple.screencapture location -string "${HOME}/Downloads"  # Save to Downloads
defaults write com.apple.screencapture type -string "jpg"                    # JPEG format

# =========================================
# Sketchybar Setup
# =========================================
echo "📊 Setting up Sketchybar..."

# Install sketchybar app font for icons
echo "Installing sketchybar font..."
curl -L https://github.com/kvndrsslr/sketchybar-app-font/releases/download/v2.0.28/sketchybar-app-font.ttf -o $HOME/Library/Fonts/sketchybar-app-font.ttf

# Install SbarLua for Lua configuration support
echo "Installing SbarLua..."
(git clone https://github.com/FelixKratz/SbarLua.git /tmp/SbarLua && cd /tmp/SbarLua/ && make install && rm -rf /tmp/SbarLua/)

# =========================================
# Clone Dotfiles Repository
# =========================================
echo "📥 Cloning dotfiles repository..."

# Clone the dots repository to home directory
cd $HOME
git clone https://github.com/justinlazarus/dots.git

# =========================================
# Configuration Symlinks
# =========================================
echo "🔗 Creating configuration symlinks..."

# Create ~/.config directory if it doesn't exist
mkdir -p ~/.config

# Symlink all configuration directories and files
ln -sf ~/dots/nvim ~/.config/nvim
ln -sf ~/dots/sketchybar ~/.config/sketchybar
ln -sf ~/dots/ghostty ~/.config/ghostty
ln -sf ~/dots/borders ~/.config/borders
ln -sf ~/dots/tmux ~/.config/tmux
ln -sf ~/dots/aerospace ~/.config/aerospace
ln -sf ~/dots/.zshrc ~/.zshrc
ln -sf ~/dots/.gitconfig ~/.gitconfig
ln -sf ~/dots/.gitignore_global ~/.gitignore_global

echo "✅ Configuration symlinks created"

# =========================================
# Manual Configuration Reminders
# =========================================
echo "📝 Manual configuration needed:"
echo "   • System Settings → Keyboard → Modifier Keys → Caps Lock: Control"
echo "   • System Settings → Privacy & Security → Accessibility → Add Terminal"
echo "   • Consider disabling other Mission Control shortcuts for yabai compatibility"

echo "✅ macOS setup completed successfully!"
echo "🔄 Restart required for all changes to take effect"
