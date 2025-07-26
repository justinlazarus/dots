#!/bin/bash

worktree_dir="$HOME/work/repos"

if [ ! -d "$worktree_dir" ]; then
    echo "Directory $worktree_dir does not exist."
    exit 1
fi

sessions=$(tmux list-sessions -F "#{session_name}" 2>/dev/null)

if [ -z "$sessions" ]; then
    echo "No tmux sessions found."
    exit 0
fi

for subdir in "$worktree_dir"/*/; do
    if [ -d "$subdir" ]; then
        session_name=$(basename "$subdir")

        if tmux has-session -t "$session_name" 2>/dev/null; then
            tmux kill-session -t "$session_name"
            echo "Killed tmux session $session_name."
        else
            echo "Session $session_name does not exist."
        fi
    fi
done

echo "All matching sesssions have been killed."
