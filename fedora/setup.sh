#!/bin/bash
set -euo pipefail

# =============================================================================
# Unified Fedora Setup Script
#
# Supported devices:
#   a1502    - MacBook Pro 13" Early 2015 (Intel Broadwell, Broadcom Wi-Fi)
#   asahi    - MacBook Air 15" 2023 (Apple M2, Fedora Asahi Remix)
#   desktop  - MSI MS-7B17 (i9-9900K, NVIDIA RTX 3070)
# =============================================================================

DOTS="$HOME/dots"

# =============================================================================
# Device picker
# =============================================================================

pick_device() {
  echo ""
  echo "┌──────────────────────────────────────┐"
  echo "│       Fedora Setup — Pick Device     │"
  echo "├──────────────────────────────────────┤"
  echo "│  1) a1502   — MacBook Pro 13\" 2015   │"
  echo "│  2) asahi   — MacBook Air 15\" M2     │"
  echo "│  3) desktop — MSI i9-9900K + 3070    │"
  echo "└──────────────────────────────────────┘"
  echo ""
  read -rp "Select device [1-3]: " choice
  case "$choice" in
    1) DEVICE="a1502"   ; CONF_DIR="$DOTS/fedora/macbook-pro-2015" ;;
    2) DEVICE="asahi"   ; CONF_DIR="$DOTS/fedora/macbook-air-m2"  ;;
    3) DEVICE="desktop" ; CONF_DIR="$DOTS/fedora/desktop-9900k"   ;;
    *) echo "Invalid selection."; exit 1 ;;
  esac
  echo ""
  echo "→ Setting up: $DEVICE"
  echo ""
}

# =============================================================================
# Common steps
# =============================================================================

setup_repos() {
  echo "📦 Enabling RPM Fusion and updating system..."
  sudo dnf install -y \
    https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
    https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
  sudo dnf upgrade -y
}

setup_env() {
  echo "🌍 Setting Wayland environment variables..."
  local extra=""
  if [[ "$DEVICE" == "desktop" ]]; then
    extra=$'\nWLR_RENDERER=pixman'
  fi
  sudo tee /etc/environment <<EOF
MOZ_ENABLE_WAYLAND=1
QT_QPA_PLATFORM=wayland
_JAVA_AWT_WM_NONREPARENTING=1
XDG_CURRENT_DESKTOP=sway
XDG_SESSION_TYPE=wayland
ELECTRON_OZONE_PLATFORM_HINT=auto${extra}
EOF
}

setup_fonts() {
  echo "🔤 Installing 0xProto Nerd Font..."
  mkdir -p ~/.local/share/fonts/0xProto
  curl -Lo /tmp/0xProto.zip https://github.com/ryanoasis/nerd-fonts/releases/latest/download/0xProto.zip
  unzip -o /tmp/0xProto.zip -d ~/.local/share/fonts/0xProto
  rm -f /tmp/0xProto.zip
  fc-cache -fv
}

setup_ghostty() {
  echo "👻 Installing Ghostty terminal..."
  sudo dnf copr enable -y pgdev/ghostty
  sudo dnf install -y ghostty
  mkdir -p ~/.config/ghostty
  ln -sf "$DOTS/ghostty/config" ~/.config/ghostty/config
}

setup_sway_configs() {
  local COMMON="$DOTS/fedora/common"

  echo "🪟 Symlinking shared configs (rofi, dunst, swaylock)..."
  mkdir -p ~/.config/rofi
  ln -sf "$COMMON/rofi/config.rasi" ~/.config/rofi/config.rasi
  ln -sf "$COMMON/rofi/tokyonight.rasi" ~/.config/rofi/tokyonight.rasi
  mkdir -p ~/.config/dunst
  ln -sf "$COMMON/dunst/dunstrc" ~/.config/dunst/dunstrc
  mkdir -p ~/.config/swaylock
  ln -sf "$COMMON/swaylock/config" ~/.config/swaylock/config

  echo "🪟 Symlinking device configs (sway, waybar)..."
  mkdir -p ~/.config/sway
  ln -sf "$CONF_DIR/sway-config" ~/.config/sway/config
  mkdir -p ~/.config/waybar
  ln -sf "$CONF_DIR/waybar/config.jsonc" ~/.config/waybar/config.jsonc
  ln -sf "$CONF_DIR/waybar/style.css" ~/.config/waybar/style.css
}

setup_dotfiles() {
  echo "🔗 Symlinking git, zsh, tmux, neovim, and vscode configs..."
  ln -sf "$DOTS/.gitconfig" ~/.gitconfig
  ln -sf "$DOTS/.zshrc" ~/.zshrc
  mkdir -p ~/.config/tmux
  ln -sf "$DOTS/tmux/tmux.conf" ~/.config/tmux/tmux.conf
  mkdir -p ~/.config/nvim
  ln -sf "$DOTS/nvim/init.lua" ~/.config/nvim/init.lua
  ln -sfn "$DOTS/nvim/lua" ~/.config/nvim/lua
  ln -sfn "$DOTS/nvim/lsp" ~/.config/nvim/lsp
  mkdir -p ~/.config/Code/User
  ln -sf "$DOTS/vscode/settings.json" ~/.config/Code/User/settings.json
  ln -sf "$DOTS/vscode/keybindings.json" ~/.config/Code/User/keybindings.json
  mkdir -p ~/.config/sworkstyle
  ln -sf "$DOTS/sworkstyle/config.toml" ~/.config/sworkstyle/config.toml
  mkdir -p ~/.local/share/applications
  ln -sf "$DOTS/applications/ghostty-ssh.desktop" ~/.local/share/applications/ghostty-ssh.desktop
}

setup_gitmux() {
  echo "📊 Installing gitmux..."
  sudo dnf install -y golang
  go install github.com/arl/gitmux@latest
  mkdir -p ~/.local/bin
  cp ~/go/bin/gitmux ~/.local/bin/gitmux
}

setup_theme() {
  echo "🎨 Installing Tokyo Night GTK theme, Papirus icons, Bibata cursor..."
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
}

setup_zram() {
  echo "💾 Tuning ZRAM (zstd compression + VM params)..."
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
}

setup_vscode_wayland() {
  echo "🖥️ Patching VS Code for native Wayland..."
  local argv="$HOME/.vscode/argv.json"
  mkdir -p "$HOME/.vscode"
  if [ -f "$argv" ]; then
    if ! grep -q 'ozone-platform' "$argv"; then
      sed -i '$ s/}/,\n\t"enable-features": "UseOzonePlatform",\n\t"ozone-platform": "wayland"\n}/' "$argv"
    fi
  else
    cat > "$argv" <<VSCEOF
{
	"enable-crash-reporter": true,
	"enable-features": "UseOzonePlatform",
	"ozone-platform": "wayland"
}
VSCEOF
  fi
}

setup_btrfs() {
  echo "💾 Adding noatime to Btrfs mounts..."
  if ! grep -q noatime /etc/fstab; then
    sudo sed -i 's/subvol=root,compress=zstd:1/subvol=root,compress=zstd:1,noatime/' /etc/fstab
    sudo sed -i 's/subvol=home,compress=zstd:1/subvol=home,compress=zstd:1,noatime/' /etc/fstab
  fi
}

setup_codecs() {
  echo "🎬 Installing multimedia codecs..."
  sudo dnf swap -y ffmpeg-free ffmpeg --allowerasing
  sudo dnf install -y gstreamer1-plugins-ugly gstreamer1-plugins-bad-free-extras
  sudo dnf install -y freetype-freeworld || true
}

# =============================================================================
# Device-specific steps
# =============================================================================

setup_a1502() {
  # Broadcom Wi-Fi + Intel Broadwell GPU
  echo "📡 Installing Wi-Fi and Intel Broadwell graphics stack..."
  sudo dnf install -y broadcom-wl akmod-wl kernel-devel \
                   vulkan-intel libva-intel-driver libva-utils
  sudo akmods --force

  # Power optimization
  echo "🔋 Tuning for battery life and thermals..."
  sudo dnf install -y powertop tlp thermald brightnessctl
  sudo systemctl enable --now thermald
  sudo systemctl enable --now tlp

  sudo tee /etc/tlp.conf <<EOF
CPU_SCALING_GOVERNOR_ON_AC=schedutil
CPU_SCALING_GOVERNOR_ON_BAT=schedutil
CPU_BOOST_ON_AC=1
CPU_BOOST_ON_BAT=0
ENERGY_PERF_POLICY_ON_AC=balance_performance
ENERGY_PERF_POLICY_ON_BAT=power
SATA_LINKPWR_ON_AC=med_power_with_dipm
SATA_LINKPWR_ON_BAT=med_power_with_dipm
WIFI_PWR_ON_AC=off
WIFI_PWR_ON_BAT=off
SOUND_POWER_SAVE_ON_AC=0
SOUND_POWER_SAVE_ON_BAT=10
SOUND_POWER_SAVE_CONTROLLER=Y
RUNTIME_PM_ON_AC=auto
RUNTIME_PM_ON_BAT=auto
USB_AUTOSUSPEND=1
EOF

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

  # Kernel params
  echo "🔧 Setting kernel parameters..."
  sudo grubby --update-kernel=ALL --args="mem_sleep_default=deep sdhci.debug_quirks2=4"

  # Apple keyboard fn keys
  echo "options hid_apple fnmode=2" | sudo tee /etc/modprobe.d/hid_apple.conf
}

setup_asahi() {
  # Mesa GPU drivers for Apple AGX
  echo "📡 Installing Mesa GPU drivers for Apple AGX..."
  sudo dnf install -y mesa-dri-drivers mesa-vulkan-drivers libva-utils

  # Install Sway stack (Asahi ships with KDE)
  echo "🪟 Installing Sway desktop environment..."
  sudo dnf install -y sway swaybg swaylock swayidle waybar rofi-wayland dunst \
                   wl-clipboard grim slurp brightnessctl playerctl

  # Remove KDE
  echo "🗑️ Removing KDE Plasma..."
  sudo dnf group remove -y "KDE Plasma Workspaces"
  sudo dnf remove -y plasma-desktop plasma-workspace kwin kscreen sddm
  sudo dnf autoremove -y
  sudo systemctl set-default graphical.target

  # Battery charge threshold
  echo "🔋 Setting battery charge threshold to 80%..."
  sudo dnf install -y brightnessctl powertop
  sudo tee /etc/udev/rules.d/90-battery-threshold.rules <<EOF
SUBSYSTEM=="power_supply", KERNEL=="macsmc-battery", ATTR{charge_control_end_threshold}="80"
EOF
  sudo udevadm control --reload-rules

  # Kernel params
  echo "🔧 Setting kernel parameters..."
  sudo grubby --update-kernel=ALL --args="apple_dcp.show_notch=1"

  # Apple keyboard fn keys
  echo "options hid_apple fnmode=2" | sudo tee /etc/modprobe.d/hid_apple.conf
}

setup_desktop() {
  # NVIDIA CUDA drivers (no desktop GPU accel — VRAM reserved for LLMs)
  echo "📡 Installing NVIDIA CUDA drivers (VRAM reserved for LLMs)..."
  sudo dnf install -y akmod-nvidia xorg-x11-drv-nvidia-cuda nvidia-gpu-firmware
  sudo akmods --force
}

# =============================================================================
# Main
# =============================================================================

pick_device

echo "🚀 Starting Fedora setup for: $DEVICE"
echo ""

setup_repos

# Device-specific drivers, power, kernel
case "$DEVICE" in
  a1502)   setup_a1502   ;;
  asahi)   setup_asahi   ;;
  desktop) setup_desktop ;;
esac

setup_env
setup_fonts
setup_ghostty
setup_sway_configs
setup_dotfiles
setup_gitmux
setup_theme
setup_zram
setup_vscode_wayland
setup_btrfs
setup_codecs

echo ""
echo "================================================================"
echo "✅ SETUP COMPLETE — $DEVICE"
echo "================================================================"

case "$DEVICE" in
  a1502)
    echo "  - Wi-Fi and graphics will be active after reboot"
    echo "  - PowerTop auto-tune enabled (improves battery ~20%)"
    ;;
  asahi)
    echo "  Post-reboot verification:"
    echo "    swaymsg -t get_outputs    # confirm display + scale"
    echo "    swaymsg -t get_inputs     # confirm touchpad"
    echo "    brightnessctl --list       # confirm kbd backlight"
    echo "    cat /sys/class/power_supply/macsmc-battery/charge_control_end_threshold"
    echo "                               # should show 80"
    echo ""
    echo "  Known limitations:"
    echo "    - Suspend draws ~2%/hr"
    echo "    - No HW video acceleration yet"
    ;;
  desktop)
    echo "  - NVIDIA CUDA drivers will be active after reboot"
    echo "  - Desktop uses software rendering (VRAM reserved for LLMs)"
    echo "  - Reload Sway (Mod+Shift+c) to pick up config changes"
    ;;
esac

echo ""
echo "Press any key to REBOOT now or Ctrl+C to exit."
read -n 1 -s
sudo reboot
