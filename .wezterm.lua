local wezterm = require 'wezterm'
local config = {}

if wezterm.config_builder then
    config = wezterm.config_builder()
end

config.color_scheme = 'OneDark (base16)'
config.font = wezterm.font 'Iosevka Nerd Font'

return config
