#!/bin/bash

worktree_dir="$HOME/work/repos"
logs_dir="$HOME/work/logs"

if [ ! -d "$worktree_dir" ]; then
    echo "Directory $worktree_dir does not exist."
    exit 1
fi

# Add a session for each directory in the worktree directory (one for each working tree)
for subdir in "$worktree_dir"/*/; do
    if [ -d "$subdir" ]; then


        session_name=$(basename "$subdir")
        session_dir="$worktree_dir/$session_name/intl-depot/"

        if [ $session_name = "intl-depot.git" ]; then
            continue
        fi

        # Check if a session with the same name already exists
        tmux has-session -t "$session_name" 2>/dev/null

        if [ $? -ne 0 ]; then

            # Create a new session and the first window for nvim
            tmux new-session -d -s "$session_name" -c "$session_dir" -n "nvim"

            # Create additional windows for nx and git
            tmux new-window -t "$session_name" -n "nx" -c "$session_dir"
            tmux new-window -t "$session_name" -n "git" -c "$session_dir"

            # select the first window
            tmux select-window -t "$session_name":1

            echo "Created new tmux session: $session_name with 3 windows"
        else
            echo "Session $session_name already exists"
        fi
    fi
done

# Add a session for logs
logs_session_name="logs"
tmux has-session -t "$logs_session_name" 2>/dev/null
if [ $? -ne 0 ]; then
    tmux new-session -d -s "$logs_session_name" -c "$logs_dir" -n "daily"
    tmux new-window -t "$logs_session_name" -n "on-call" -c "$logs_dir"
    tmux select-window -t "$logs_session_name":1
    echo "Created new tmux session: $logs_session_name with 2 windows"
else
    echo "Logs session already exists"
fi
