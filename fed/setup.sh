#!/bin/bash

# =============================================================================
# Device: MacBook Pro 13" Early 2015 (A1502 - EMC 2835)
# OS: Fedora 43 Sway Spin (Linux-Only)
# Target: Developer Workstation / Caps-as-Control / Power Optimized
# =============================================================================

echo "🚀 Starting A1502 (Early 2015) Optimized Setup..."

# 1. REPOSITORIES & UPDATES
echo "📦 Enabling RPM Fusion and updating system..."
sudo dnf install -y https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
                 https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
sudo dnf upgrade -y

# 2. DRIVERS & HARDWARE STACK
echo "📡 Installing Wi-Fi and Intel Broadwell Graphics Stack..."
# BCM43602 firmware + Broadcom driver
sudo dnf install -y broadcom-wl akmod-wl kernel-devel \
                 vulkan-intel intel-media-driver libva-utils
sudo akmods --force

# 3. POWER OPTIMIZATION (PowerTop + TLP + Thermald)
echo "🔋 Tuning for battery life and thermals..."
sudo dnf install -y powertop tlp thermald brightnessctl
sudo systemctl enable --now thermald
sudo systemctl enable --now tlp

# Create a systemd service to auto-tune PowerTop on every boot
sudo tee /etc/systemd/system/powertop-autotune.service <<EOF
[Unit]
Description=PowerTop Auto-tune
[Service]
Type=oneshot
ExecStart=/usr/sbin/powertop --auto-tune
[Install]
WantedBy=multi-user.target
EOF
sudo systemctl enable powertop-autotune.service

# 4. KERNEL & BOOT PARAMS
echo "🔧 Setting kernel parameters..."
# mem_sleep_default=deep: Crucial for S3 sleep on A1502
# sdhci.debug_quirks2=4: Fixes SD Card reader speed/reliability if needed
sudo grubby --update-kernel=ALL --args="mem_sleep_default=deep sdhci.debug_quirks2=4"

# Fix Function Keys (F1-F12 as primary, Fn+Key for Media)
echo "options hid_apple fnmode=2" | sudo tee /etc/modprobe.d/hid_apple.conf

# 5. ENVIRONMENT VARIABLES (Sway Wiki Best Practices)
echo "🌍 Setting Wayland environment variables..."
sudo tee /etc/environment <<EOF
MOZ_ENABLE_WAYLAND=1
QT_QPA_PLATFORM=wayland
_JAVA_AWT_WM_NONREPARENTING=1
XDG_CURRENT_DESKTOP=sway
XDG_SESSION_TYPE=wayland
EOF

# 6. SWAY CONFIGURATION (HiDPI & Inputs)
echo "🖥️ Writing Sway configs..."
mkdir -p ~/.config/sway/config.d

# Display: 1.5x Scaling for 13" Retina
cat <<EOF > ~/.config/sway/config.d/01-display.conf
output "eDP-1" scale 1.5
EOF

# Input: Trackpad + Caps-to-Control (nocaps)
cat <<EOF > ~/.config/sway/config.d/02-input.conf
input "type:keyboard" {
    xkb_options ctrl:nocaps
}
input "type:touchpad" {
    tap enabled
    natural_scroll enabled
    dwt enabled
    pointer_accel 0.3
    accel_profile "flat"
}
EOF

# Keybinds: Audio & Brightness
cat <<EOF > ~/.config/sway/config.d/03-keybinds.conf
bindsym XF86AudioRaiseVolume exec wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+
bindsym XF86AudioLowerVolume exec wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
bindsym XF86AudioMute exec wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
bindsym XF86MonBrightnessUp exec brightnessctl set 5%+
bindsym XF86MonBrightnessDown exec brightnessctl set 5%-
EOF

# 7. FONTS
echo "🔤 Installing 0xProto Nerd Font..."
mkdir -p ~/.local/share/fonts/0xProto
curl -Lo /tmp/0xProto.zip https://github.com/ryanoasis/nerd-fonts/releases/latest/download/0xProto.zip
unzip -o /tmp/0xProto.zip -d ~/.local/share/fonts/0xProto
rm -f /tmp/0xProto.zip
fc-cache -fv

# 8. GHOSTTY TERMINAL
echo "👻 Installing Ghostty terminal..."
sudo dnf copr enable -y pgdev/ghostty
sudo dnf install -y ghostty

# Symlink Ghostty config
mkdir -p ~/.config/ghostty
ln -sf ~/dots/ghostty/config ~/.config/ghostty/config

# 8. SWAY CONFIG
echo "🪟 Symlinking sway config..."
ln -sf ~/dots/fed/sway-config ~/.config/sway/config
mkdir -p ~/.config/waybar
ln -sf ~/dots/fed/waybar/config.jsonc ~/.config/waybar/config.jsonc
ln -sf ~/dots/fed/waybar/style.css ~/.config/waybar/style.css

# 9. DOTFILE SYMLINKS (zsh, tmux, neovim)
echo "🔗 Symlinking zsh, tmux, and neovim configs..."
ln -sf ~/dots/.zshrc ~/.zshrc
mkdir -p ~/.config/tmux
ln -sf ~/dots/tmux/tmux.conf ~/.config/tmux/tmux.conf
mkdir -p ~/.config/nvim
ln -sf ~/dots/nvim/init.lua ~/.config/nvim/init.lua
ln -sfn ~/dots/nvim/lua ~/.config/nvim/lua
ln -sfn ~/dots/nvim/lsp ~/.config/nvim/lsp

# 10. GITMUX (tmux git status)
echo "📊 Installing gitmux..."
go install github.com/arl/gitmux@latest
cp ~/go/bin/gitmux ~/.local/bin/gitmux

# 11. MULTIMEDIA CODECS
echo "🎬 Installing Hardware Codecs..."
sudo dnf swap -y ffmpeg-free ffmpeg --allowerasing
sudo dnf install -y gstreamer1-plugins-ugly gstreamer1-plugins-bad-free-extras freetype-freeworld

echo "----------------------------------------------------------------"
echo "✅ A1502 SETUP COMPLETE"
echo "----------------------------------------------------------------"
echo "1. Wi-Fi and Graphics will be active after REBOOT."
echo "2. PowerTop auto-tune is enabled (improves battery by ~20%)."
echo "3. Caps Lock is now Control."
echo ""
echo "Press any key to REBOOT now or Ctrl+C to exit."
read -n 1 -s
sudo reboot
