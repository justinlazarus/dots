#!/bin/bash

# =============================================================================
# Device: MSI MS-7B17 Desktop
# CPU: Intel Core i9-9900K | GPU: NVIDIA RTX 3070 | RAM: 32GB
# OS: Fedora 43 Sway Spin
# =============================================================================

echo "Starting desktop setup..."

# 1. REPOSITORIES & UPDATES
echo "Enabling RPM Fusion and updating system..."
sudo dnf install -y https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
                 https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
sudo dnf upgrade -y

# 2. NVIDIA DRIVERS (CUDA/compute only — desktop uses software rendering)
# Keeps all VRAM free for local LLM inference
echo "Installing NVIDIA CUDA drivers (no desktop GPU acceleration)..."
sudo dnf install -y akmod-nvidia xorg-x11-drv-nvidia-cuda nvidia-gpu-firmware
sudo akmods --force

# 3. ENVIRONMENT VARIABLES
echo "Setting Wayland environment variables..."
sudo tee /etc/environment <<EOF
MOZ_ENABLE_WAYLAND=1
QT_QPA_PLATFORM=wayland
_JAVA_AWT_WM_NONREPARENTING=1
XDG_CURRENT_DESKTOP=sway
XDG_SESSION_TYPE=wayland
WLR_RENDERER=pixman
EOF

# 4. FONTS
echo "Installing 0xProto Nerd Font..."
mkdir -p ~/.local/share/fonts/0xProto
curl -Lo /tmp/0xProto.zip https://github.com/ryanoasis/nerd-fonts/releases/latest/download/0xProto.zip
unzip -o /tmp/0xProto.zip -d ~/.local/share/fonts/0xProto
rm -f /tmp/0xProto.zip
fc-cache -fv

# 5. GHOSTTY TERMINAL
echo "Installing Ghostty..."
sudo dnf copr enable -y pgdev/ghostty
sudo dnf install -y ghostty
mkdir -p ~/.config/ghostty
ln -sf ~/dots/ghostty/config ~/.config/ghostty/config

# 6. SWAY + WAYBAR + ROFI + DUNST + SWAYLOCK CONFIG
echo "Symlinking sway, waybar, rofi, dunst, swaylock configs..."
mkdir -p ~/.config/sway
ln -sf ~/dots/feddesk/sway-config ~/.config/sway/config
mkdir -p ~/.config/waybar
ln -sf ~/dots/feddesk/waybar/config.jsonc ~/.config/waybar/config.jsonc
ln -sf ~/dots/feddesk/waybar/style.css ~/.config/waybar/style.css
mkdir -p ~/.config/rofi
ln -sf ~/dots/feddesk/rofi/config.rasi ~/.config/rofi/config.rasi
ln -sf ~/dots/feddesk/rofi/tokyonight.rasi ~/.config/rofi/tokyonight.rasi
mkdir -p ~/.config/dunst
ln -sf ~/dots/feddesk/dunst/dunstrc ~/.config/dunst/dunstrc
mkdir -p ~/.config/swaylock
ln -sf ~/dots/feddesk/swaylock/config ~/.config/swaylock/config

# 7. DOTFILE SYMLINKS (git, zsh, tmux, neovim)
echo "Symlinking git, zsh, tmux, and neovim configs..."
ln -sf ~/dots/.gitconfig ~/.gitconfig
ln -sf ~/dots/.zshrc ~/.zshrc
mkdir -p ~/.config/tmux
ln -sf ~/dots/tmux/tmux.conf ~/.config/tmux/tmux.conf
mkdir -p ~/.config/nvim
ln -sf ~/dots/nvim/init.lua ~/.config/nvim/init.lua
ln -sfn ~/dots/nvim/lua ~/.config/nvim/lua
ln -sfn ~/dots/nvim/lsp ~/.config/nvim/lsp

# 8. GOLANG + GITMUX
echo "Installing Go and gitmux..."
sudo dnf install -y golang
go install github.com/arl/gitmux@latest
mkdir -p ~/.local/bin
cp ~/go/bin/gitmux ~/.local/bin/gitmux

# 9. GTK THEME, ICONS & CURSOR
echo "Installing Tokyo Night GTK theme, Papirus icons, Bibata cursor..."
sudo dnf install -y sassc papirus-icon-theme
rm -rf /tmp/tokyonight-gtk
git clone https://github.com/Fausto-Korpsvart/Tokyo-Night-GTK-Theme.git /tmp/tokyonight-gtk
/tmp/tokyonight-gtk/themes/install.sh -c dark --tweaks storm outline -l
rm -rf /tmp/tokyonight-gtk

curl -sL https://github.com/ful1e5/Bibata_Cursor/releases/latest/download/Bibata-Modern-Classic.tar.xz -o /tmp/bibata.tar.xz
mkdir -p ~/.local/share/icons
tar xf /tmp/bibata.tar.xz -C ~/.local/share/icons/
rm -f /tmp/bibata.tar.xz

gsettings set org.gnome.desktop.interface gtk-theme "Tokyonight-Dark-Storm"
gsettings set org.gnome.desktop.interface color-scheme "prefer-dark"
gsettings set org.gnome.desktop.interface icon-theme "Papirus-Dark"
gsettings set org.gnome.desktop.interface cursor-theme "Bibata-Modern-Classic"
gsettings set org.gnome.desktop.interface cursor-size 24

# 10. ZRAM TUNING
echo "Tuning ZRAM..."
sudo tee /etc/systemd/zram-generator.conf <<EOF
[zram0]
zram-size = min(ram, 8192)
compression-algorithm = zstd
EOF

sudo tee /etc/sysctl.d/99-zram.conf <<EOF
vm.swappiness = 180
vm.page-cluster = 0
vm.watermark_boost_factor = 0
vm.watermark_scale_factor = 125
EOF
sudo sysctl --load /etc/sysctl.d/99-zram.conf

# 11. BTRFS noatime
echo "Adding noatime to Btrfs mounts..."
grep -q 'noatime' /etc/fstab || {
  sudo sed -i 's/subvol=root,compress=zstd:1/subvol=root,compress=zstd:1,noatime/' /etc/fstab
  sudo sed -i 's/subvol=home,compress=zstd:1/subvol=home,compress=zstd:1,noatime/' /etc/fstab
}

# 12. MULTIMEDIA CODECS
echo "Installing multimedia codecs..."
sudo dnf swap -y ffmpeg-free ffmpeg --allowerasing
sudo dnf install -y gstreamer1-plugins-ugly gstreamer1-plugins-bad-free-extras freetype-freeworld

echo "----------------------------------------------------------------"
echo "SETUP COMPLETE"
echo "----------------------------------------------------------------"
echo "1. NVIDIA CUDA drivers will be active after REBOOT."
echo "2. Desktop uses software rendering (VRAM reserved for LLMs)."
echo "3. Reload Sway (Mod+Shift+c) to pick up config changes."
echo ""
echo "Press any key to REBOOT now or Ctrl+C to exit."
read -n 1 -s
sudo reboot
