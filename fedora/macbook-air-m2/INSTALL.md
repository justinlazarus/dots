# Fedora Asahi Remix on MacBook Air 15" M2 (2023)

## 1. Prerequisites

- macOS 13.5+ or 14.2+ required (intermediate versions may need upgrade to 14.2)
- Decide how much disk space to allocate to Linux (recommend 80-100GB+)
- Back up macOS data

## 2. Partitioning Strategy

Run the installer first to **view** disk layout without making changes (quit when prompted):

```sh
curl https://alx.sh | sh
```

The installer creates 3 partitions:

1. **2.5GB APFS container** -- macOS stub bootloader, m1n1 stage 1, recoveryOS copy
2. **500MB EFI System Partition** -- m1n1 stage 2, U-Boot, GRUB
3. **Remaining allocated space** -- Linux root (ext4 by default, Btrfs if chosen)

**NEVER delete `Apple_APFS_Recovery`** -- breaks macOS upgrades, requires factory restore.

To check partitions from macOS:

```sh
diskutil list
```

Note: synthesized disk numbers are unstable across reboots.

To resize macOS and reclaim space later:

```sh
diskutil apfs resizeContainer disk0s2 0
```

## 3. Installation

```sh
curl https://fedora-asahi-remix.org/install | sh
```

- Choose **Fedora Asahi Remix** (not minimal -- we need the base Fedora packages)
- Select desktop environment: **KDE Plasma** (default; we replace with Sway via setup.sh)
- Allocate disk space when prompted
- Follow prompts to completion, then reboot

## 4. First Boot

1. Machine boots into Fedora Asahi Remix KDE
2. Connect to WiFi, verify hardware (display, trackpad, audio)
3. Clone this repo:

```sh
git clone https://github.com/justinlazarus/dots.git ~/dots
```

4. Run setup:

```sh
chmod +x ~/dots/fedasahi/setup.sh && ~/dots/fedasahi/setup.sh
```

5. Reboot into Sway after setup completes

## 5. Dual-Boot Notes

- Default boot OS set via macOS System Settings or Option-key at startup
- Each Asahi install gets its own ESP + stub container as one logical unit
- Native Apple boot picker (hold Option at startup) selects between OSes

## 6. Uninstall / Recovery

Set macOS as default boot **before** removing Asahi.

```sh
# Delete APFS stub
diskutil apfs deleteContainer diskXsY

# Delete EFI + Linux partitions
diskutil eraseVolume free free diskXsY

# Reclaim space
diskutil apfs resizeContainer disk0s2 0
```

**Never use Disk Utility GUI** -- unreliable for complex layouts.
