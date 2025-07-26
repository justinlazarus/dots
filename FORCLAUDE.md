# macOS Rice Setup - Rosé Pine Theme

## Current Status
Successfully transformed the macOS setup from Catppuccin to Rosé Pine theme across all components.

## What We Accomplished

### 1. Ghostty Terminal Configuration
- **File**: `ghostty/config`
- **Changes**:
  - Switched theme from `catppuccin-mocha` to `rose-pine`
  - Added transparency: `background-opacity = 0.95`
  - Enabled ligatures: `font-feature = +liga,+calt,+ss01,+ss02,+ss03,+ss04,+ss05,+ss06,+ss07,+ss08,+ss09`
  - Added font variation: `font-variation-feature = "wght:400"`

### 2. Neovim Configuration
- **File**: `nvim/lua/plugins/colorschemes.lua`
- **Changes**:
  - Added `rose-pine/neovim` plugin with priority 1000
  - Set as active colorscheme: `vim.api.nvim_command 'colorscheme rose-pine'`
  - Disabled Catppuccin as default (commented out activation line)

### 3. Sketchybar Status Bar
- **Action**: Fresh installation and configuration
- **Version**: Upgraded to v2.22.1 (latest)
- **Location**: `sketchybar/` directory with symlinks to `~/.config/sketchybar/`
- **Files Created**:
  - `sketchybarrc` - Main configuration
  - `colors.sh` - Rosé Pine color definitions
  - `plugins/aerospace.sh` - Aerospace workspace integration

#### Sketchybar Features
- **Theme**: Full Rosé Pine color scheme
- **Integration**: Aerospace workspace indicators (1-6)
- **Font**: Iosevka Term Nerd Font (matching Ghostty)
- **Transparency**: Semi-transparent bar background
- **Workspace Switching**: Click to switch between Aerospace workspaces

#### Color Scheme (Rosé Pine)
```bash
BASE="0xff191724"       # base
SURFACE="0xff1f1d2e"    # surface  
OVERLAY="0xff26233a"    # overlay
TEXT="0xffe0def4"       # text
LOVE="0xffeb6f92"       # love
GOLD="0xfff6c177"       # gold
PINE="0xff31748f"       # pine (accent)
FOAM="0xff9ccfd8"       # foam
IRIS="0xffc4a7e7"       # iris
```

### 4. macOS System Integration
- **Menu Bar**: Hidden macOS menu bar (`defaults write NSGlobalDomain _HIHideMenuBar -bool true`)
- **Note**: May require logout/login to fully take effect

## Current Setup Summary
- **Terminal**: Ghostty with Rosé Pine theme, 95% opacity, advanced ligatures
- **Editor**: Neovim with Rose Pine colorscheme
- **Status Bar**: Sketchybar v2.22.1 with custom Rosé Pine theme
- **Window Manager**: Aerospace (6 workspaces, already configured)
- **Font**: Iosevka Term with extensive ligature support

## Files Modified/Created
```
dots/
├── ghostty/config (modified)
├── nvim/lua/plugins/colorschemes.lua (modified)
├── sketchybar/ (new directory)
│   ├── sketchybarrc
│   ├── colors.sh
│   └── plugins/
│       └── aerospace.sh
└── sketchybar.backup/ (backup of old config)
```

## Symlinks Created
- `~/.config/sketchybar/sketchybarrc` → `/Users/djpoo/dots/sketchybar/sketchybarrc`
- `~/.config/sketchybar/plugins` → `/Users/djpoo/dots/sketchybar/plugins`

## Next Steps (if desired)
- Logout/login to fully hide macOS menu bar
- Customize Sketchybar plugins (battery, clock, volume)
- Fine-tune colors or add more visual elements
- Explore additional Iosevka font variants or stylistic sets

## Troubleshooting
- If Sketchybar isn't visible: Check if macOS menu bar is hidden, restart Sketchybar with `sketchybar --reload`
- If themes don't apply: Restart applications (Ghostty, Neovim)
- To start Sketchybar: `sketchybar -d` (daemon mode)