#!/bin/sh
git -C "$1" rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0
out=$(gitmux -cfg "$HOME/.config/tmux/.gitmuxconfig" "$1" 2>/dev/null)
[ -z "$out" ] && exit 0
printf '#[fg=#1e1e2e,bg=#a6e3a1] %-30s' "$out"
