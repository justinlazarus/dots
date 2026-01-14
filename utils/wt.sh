#!/bin/bash
export PATH=$PATH:/usr/local/bin:/usr/bin:/bin:/opt/homebrew/bin

# 1. Get Absolute Path of the Main Repo
# We use 'rev-parse --git-common-dir' to find the actual .git folder location
GIT_COMMON=$(git rev-parse --git-common-dir 2>/dev/null)
if [ -z "$GIT_COMMON" ]; then
    echo "Error: Not in a git repo"; sleep 2; exit 1
fi

# Standardize the Main Repo Path (Removing the /.git part)
MAIN_REPO_PATH=$(realpath "$GIT_COMMON/..")
PARENT_DIR=$(dirname "$MAIN_REPO_PATH")
REPO_NAME=$(basename "$MAIN_REPO_PATH")

# 2. Select Branch
selected=$(git branch --all --format='%(refname:short)' | grep -v 'HEAD' | fzf --height=40% --reverse --header="Select Branch")
[ -z "$selected" ] && exit 0

# 3. Resolve Branch Name (Handling 'origin/feature' vs 'feature')
# If it starts with origin/, we strip it for the folder name
branch_name="${selected#origin/}"
folder_suffix=$(echo "$branch_name" | tr '/' '-')

# 4. Define the ABSOLUTE Target Directory
target_dir="$PARENT_DIR/$REPO_NAME-$folder_suffix"
session_name="$REPO_NAME-$folder_suffix"

# 5. Create Worktree if it doesn't exist
if [ ! -d "$target_dir" ]; then
    echo "Creating worktree at: $target_dir"
    
    # If the branch is remote-only, we must track it explicitly
    if git rev-parse --verify "$branch_name" >/dev/null 2>&1; then
        git worktree add "$target_dir" "$branch_name"
    else
        git worktree add -b "$branch_name" "$target_dir" "origin/$branch_name"
    fi

    # CRITICAL: If the folder still doesn't exist, Git failed. STOP HERE.
    if [ ! -d "$target_dir" ]; then
        echo "FAILED: Git could not create the directory."
        read -p "Press Enter to see error..."
        exit 1
    fi
fi

# 6. Tmux Session Logic
if ! tmux has-session -t "$session_name" 2>/dev/null; then
    # Create the session and the first window named 'nvim'
    # We use -d to build it in the background
    tmux new-session -d -s "$session_name" -c "$target_dir" -n "nvim"
    
    # Create the second window named 'git'
    tmux new-window -t "$session_name" -c "$target_dir" -n "git"
    
    # Create the third window named 'nx'
    tmux new-window -t "$session_name" -c "$target_dir" -n "nx"
    
    # Optional: Automatically start nvim in the first window
    # tmux send-keys -t "$session_name:nvim" "nvim ." C-m
    
    # Ensure the 'nvim' window is the one focused when you switch in
    tmux select-window -t "$session_name:nvim"
fi

# 7. Switch to session
if [ -n "$TMUX" ]; then
    tmux switch-client -t "$session_name"
else
    tmux attach-session -t "$session_name"
fi
