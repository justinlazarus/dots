#!/bin/bash

worktree_dir="$HOME/work/repos"

if [ ! -d "$worktree_dir" ]; then
    echo "Directory $worktree_dir does not exist."
    exit 1
fi

for subdir in "$worktree_dir"/*/; do
    if [ -d "$subdir" ]; then
        session_name=$(basename "$subdir")
        session_dir="$worktree_dir/$session_name/intl-depot/"

        # Check if a session with the same name already exists
        tmux has-session -t "$session_name" 2>/dev/null

        if [ $? -ne 0 ]; then

            # Create a new session and the first window for nvim
            tmux new-session -d -s "$session_name" -c "$session_dir" -n "nvim"

            # Create additional windows for nx and git
            tmux new-window -t "$session_name" -n "nx" -c "$session_dir"
            tmux new-window -t "$session_name" -n "git" -c "$session_dir"

            # select the first window
            tmux select-window -t "$session_name":0

            echo "Created new tmux session: $session_name with 3 windows"
        else
            echo "Session $session_name already exists"
        fi
    fi
done
