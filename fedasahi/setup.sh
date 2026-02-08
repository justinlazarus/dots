#!/bin/bash

# =============================================================================
# Device: MacBook Air 15" 2023 (M2, 8GB RAM)
# OS: Fedora Asahi Remix (KDE base -> Sway)
# Target: Developer Workstation / Caps-as-Control / Power Optimized
# =============================================================================

echo "Starting M2 MacBook Air 15\" Asahi Setup..."

# 1. REPOSITORIES & UPDATES
echo "Enabling RPM Fusion and updating system..."
sudo dnf install -y https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
                 https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
sudo dnf upgrade -y

# 2. DRIVERS & HARDWARE STACK
echo "Installing Mesa GPU drivers for Apple AGX..."
sudo dnf install -y mesa-dri-drivers mesa-vulkan-drivers libva-utils

# 3. SWAY + WAYLAND STACK
echo "Installing Sway desktop environment..."
sudo dnf install -y sway swaybg swaylock swayidle waybar rofi-wayland dunst \
                 wl-clipboard grim slurp brightnessctl playerctl

# 3b. REMOVE KDE
echo "Removing KDE Plasma..."
sudo dnf group remove -y "KDE Plasma Workspaces"
sudo dnf remove -y plasma-desktop plasma-workspace kwin kscreen sddm
sudo dnf autoremove -y
sudo systemctl set-default graphical.target

# 4. POWER MANAGEMENT
echo "Configuring power management for M2..."
sudo dnf install -y brightnessctl powertop

# Battery charge threshold at 80% via udev rule (macsmc-battery)
sudo tee /etc/udev/rules.d/90-battery-threshold.rules <<EOF
SUBSYSTEM=="power_supply", KERNEL=="macsmc-battery", ATTR{charge_control_end_threshold}="80"
EOF
sudo udevadm control --reload-rules

# 5. KERNEL & BOOT PARAMS
echo "Setting kernel parameters..."
# apple_dcp.show_notch=1: enables usable screen area around the notch
sudo grubby --update-kernel=ALL --args="apple_dcp.show_notch=1"

# Fix Function Keys (F1-F12 as primary, Fn+Key for Media)
echo "options hid_apple fnmode=2" | sudo tee /etc/modprobe.d/hid_apple.conf

# 6. ENVIRONMENT VARIABLES (Sway Wiki Best Practices)
echo "Setting Wayland environment variables..."
sudo tee /etc/environment <<EOF
MOZ_ENABLE_WAYLAND=1
QT_QPA_PLATFORM=wayland
_JAVA_AWT_WM_NONREPARENTING=1
XDG_CURRENT_DESKTOP=sway
XDG_SESSION_TYPE=wayland
EOF

# 7. FONTS
echo "Installing 0xProto Nerd Font..."
mkdir -p ~/.local/share/fonts/0xProto
curl -Lo /tmp/0xProto.zip https://github.com/ryanoasis/nerd-fonts/releases/latest/download/0xProto.zip
unzip -o /tmp/0xProto.zip -d ~/.local/share/fonts/0xProto
rm -f /tmp/0xProto.zip
fc-cache -fv

# 8. GHOSTTY TERMINAL
echo "Installing Ghostty terminal..."
sudo dnf copr enable -y pgdev/ghostty
sudo dnf install -y ghostty

# Symlink Ghostty config
mkdir -p ~/.config/ghostty
ln -sf ~/dots/ghostty/config ~/.config/ghostty/config

# 9. SWAY + WAYBAR + ROFI + DUNST + SWAYLOCK CONFIG
echo "Symlinking sway, waybar, rofi, dunst, swaylock configs..."
mkdir -p ~/.config/sway
ln -sf ~/dots/fedasahi/sway-config ~/.config/sway/config
mkdir -p ~/.config/waybar
ln -sf ~/dots/fedasahi/waybar/config.jsonc ~/.config/waybar/config.jsonc
ln -sf ~/dots/fedasahi/waybar/style.css ~/.config/waybar/style.css
mkdir -p ~/.config/rofi
ln -sf ~/dots/fedasahi/rofi/config.rasi ~/.config/rofi/config.rasi
ln -sf ~/dots/fedasahi/rofi/tokyonight.rasi ~/.config/rofi/tokyonight.rasi
mkdir -p ~/.config/dunst
ln -sf ~/dots/fedasahi/dunst/dunstrc ~/.config/dunst/dunstrc
mkdir -p ~/.config/swaylock
ln -sf ~/dots/fedasahi/swaylock/config ~/.config/swaylock/config

# 10. DOTFILE SYMLINKS (git, zsh, tmux, neovim)
echo "Symlinking git, zsh, tmux, and neovim configs..."
ln -sf ~/dots/.gitconfig ~/.gitconfig
ln -sf ~/dots/.djshrc ~/.zshrc
mkdir -p ~/.config/tmux
ln -sf ~/dots/tmux/tmux.conf ~/.config/tmux/tmux.conf
mkdir -p ~/.config/nvim
ln -sf ~/dots/nvim/init.lua ~/.config/nvim/init.lua
ln -sfn ~/dots/nvim/lua ~/.config/nvim/lua
ln -sfn ~/dots/nvim/lsp ~/.config/nvim/lsp

# 11. GITMUX (tmux git status)
echo "Installing gitmux..."
sudo dnf install -y golang
go install github.com/arl/gitmux@latest
mkdir -p ~/.local/bin
cp ~/go/bin/gitmux ~/.local/bin/gitmux
ln -sf ~/dots/tmux/.gitmuxconfig ~/.config/tmux/.gitmuxconfig

# 12. GTK THEME, ICONS & CURSOR
echo "Installing Tokyo Night GTK theme, Papirus icons, Bibata cursor..."
sudo dnf install -y sassc papirus-icon-theme
git clone https://github.com/Fausto-Korpsvart/Tokyo-Night-GTK-Theme.git /tmp/tokyonight-gtk
/tmp/tokyonight-gtk/themes/install.sh -c dark --tweaks storm outline -l
rm -rf /tmp/tokyonight-gtk

# Bibata cursor
curl -sL https://github.com/ful1e5/Bibata_Cursor/releases/latest/download/Bibata-Modern-Classic.tar.xz -o /tmp/bibata.tar.xz
mkdir -p ~/.local/share/icons
tar xf /tmp/bibata.tar.xz -C ~/.local/share/icons/
rm -f /tmp/bibata.tar.xz

# Apply themes
gsettings set org.gnome.desktop.interface gtk-theme "Tokyonight-Dark-Storm"
gsettings set org.gnome.desktop.interface color-scheme "prefer-dark"
gsettings set org.gnome.desktop.interface icon-theme "Papirus-Dark"
gsettings set org.gnome.desktop.interface cursor-theme "Bibata-Modern-Classic"
gsettings set org.gnome.desktop.interface cursor-size 24

# 13. ZRAM TUNING
echo "Tuning ZRAM (zstd compression + VM params)..."
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

# 14. BTRFS noatime
echo "Adding noatime to Btrfs mounts..."
if ! grep -q noatime /etc/fstab; then
    sudo sed -i 's/subvol=root,compress=zstd:1/subvol=root,compress=zstd:1,noatime/' /etc/fstab
    sudo sed -i 's/subvol=home,compress=zstd:1/subvol=home,compress=zstd:1,noatime/' /etc/fstab
fi

# 15. MULTIMEDIA CODECS
echo "Installing multimedia codecs..."
sudo dnf swap -y ffmpeg-free ffmpeg --allowerasing
sudo dnf install -y gstreamer1-plugins-ugly gstreamer1-plugins-bad-free-extras
sudo dnf install -y freetype-freeworld || true

# 16. VERIFICATION
echo "----------------------------------------------------------------"
echo "M2 MBA ASAHI SETUP COMPLETE"
echo "----------------------------------------------------------------"
echo ""
echo "Post-reboot verification checklist:"
echo "  swaymsg -t get_outputs        # confirm display name and scale"
echo "  swaymsg -t get_inputs         # confirm touchpad device"
echo "  brightnessctl --list           # confirm kbd backlight device"
echo "  cat /sys/class/power_supply/macsmc-battery/charge_control_end_threshold"
echo "                                 # should show 80"
echo ""
echo "Known limitations:"
echo "  - Suspend draws ~2%/hr"
echo "  - No HW video acceleration yet"
echo ""
echo "Press any key to REBOOT now or Ctrl+C to exit."
read -n 1 -s
sudo reboot
