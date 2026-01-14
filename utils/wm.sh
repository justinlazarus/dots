#!/bin/zsh
export PATH=$PATH:/usr/local/bin:/usr/bin:/bin:/opt/homebrew/bin:/opt/homebrew/sbin

# 1. Validation
COMMON_DIR=$(git rev-parse --git-common-dir 2>/dev/null)
[[ -z "$COMMON_DIR" ]] && echo "Not a git repo." && exit 1

MAIN_REPO_PATH=$(realpath "$COMMON_DIR/..")
REPO_NAME=$(basename "$MAIN_REPO_PATH" | tr '.' '-')
PARENT_DIR=$(dirname "$MAIN_REPO_PATH")

# 2. Data Collection
local -a raw_list
typeset -A seen_branches
TAB=$'\t'

# --- PART A: Existing Worktrees (Boosted Priority) ---
while read -r line; do
    if [[ $line == worktree* ]]; then
        current_path="${line#worktree }"
    elif [[ $line == branch* ]]; then
        full_branch="${line#branch refs/heads/}"
        seen_branches[$full_branch]=1
        
        safe_branch=${full_branch//\//-}
        safe_branch=${safe_branch//./-}
        session_name="$REPO_NAME-$safe_branch"
        
        # Check Tmux State
        if tmux has-session -t "$session_name" 2>/dev/null; then
            state="●"
            # Active Session Boost: Add 20 Billion to timestamp
            boost=20000000000
        else
            state="○"
            # Paused Worktree Boost: Add 10 Billion to timestamp
            boost=10000000000
        fi
        
        # Get raw timestamp
        ts=$(git log -1 --format="%ct" "$full_branch" 2>/dev/null)
        [[ -z "$ts" ]] && ts=0
        
        # Apply Boost
        (( ts += boost ))
        
        raw_list+=("${ts}${TAB}${state} | ${full_branch}${TAB}${full_branch}${TAB}${current_path}${TAB}${full_branch}")
    fi
done < <(git worktree list --porcelain)

# --- PART B: New Branches (Standard Priority) ---
while IFS='|' read -r ts ref; do
    if [[ "$ref" == refs/heads/* ]]; then
        clean="${ref#refs/heads/}"
    elif [[ "$ref" == refs/remotes/origin/* ]]; then
        clean="${ref#refs/remotes/origin/}"
    else
        continue
    fi

    [[ "$clean" == "HEAD" ]] && continue
    [[ -n "${seen_branches[$clean]}" ]] && continue

    seen_branches[$clean]=1
    
    # New branches get NO boost, so they appear after worktrees
    raw_list+=("${ts}${TAB}+ | ${clean}${TAB}${clean}${TAB}CREATE_NEEDED${TAB}${ref}")

done < <(git for-each-ref --sort=-committerdate --format='%(committerdate:unix)|%(refname)' refs/heads refs/remotes/origin)

# 3. FZF Selection
PREVIEW_CMD="git log --color=always --graph --format='%C(yellow)%h%C(reset) %C(green)(%ar)%C(reset) %C(blue)<%an>%C(reset) %s' {5} 2>/dev/null"

selected=$(print -l "${raw_list[@]}" | sort -rn | fzf --ansi \
    --delimiter "$TAB" \
    --with-nth 2 \
    --header 'ENTER: Switch | CTRL-X: Kill | CTRL-D: Delete' \
    --preview "$PREVIEW_CMD" \
    --preview-window 'right:55%:wrap' \
    --reverse \
    --expect=ctrl-x,ctrl-d)

[[ -z "$selected" ]] && exit 0

# Parse Selection
key=$(echo "$selected" | sed -n '1p')
line=$(echo "$selected" | sed -n '2p')
[[ -z "$line" ]] && exit 0

# Extract Data
branch=$(echo "$line" | cut -f3)
target_dir=$(echo "$line" | cut -f4)

# Trim whitespace
branch="${branch#"${branch%%[![:space:]]*}"}"   
branch="${branch%"${branch##*[![:space:]]}"}"
target_dir="${target_dir#"${target_dir%%[![:space:]]*}"}"   
target_dir="${target_dir%"${target_dir##*[![:space:]]}"}"

# Session Naming
safe_branch=${branch//\//-}
safe_branch=${safe_branch//./-}
session_name="$REPO_NAME-$safe_branch"

# 4. Actions
if [[ "$key" == "ctrl-x" ]]; then
    tmux kill-session -t "$session_name" 2>/dev/null
    exit 0
elif [[ "$key" == "ctrl-d" ]]; then
    [[ "$target_dir" == "$MAIN_REPO_PATH" ]] && exit 1
    tmux kill-session -t "$session_name" 2>/dev/null
    git worktree remove "$target_dir" --force
    exit 0
fi

# 5. Create Logic
if [[ "$target_dir" == "CREATE_NEEDED" ]]; then
    target_dir="$PARENT_DIR/$REPO_NAME-$safe_branch"
    if [[ ! -d "$target_dir" ]]; then
        if git show-ref --verify --quiet "refs/heads/$branch"; then
            git worktree add "$target_dir" "$branch"
        else
            git worktree add -b "$branch" "$target_dir" "origin/$branch"
        fi
    fi
fi

# 6. Session Creation
if ! tmux has-session -t "$session_name" 2>/dev/null; then
    count=0
    while [[ ! -d "$target_dir" && $count -lt 20 ]]; do
        sleep 0.1
        ((count++))
    done
    
    if [[ ! -d "$target_dir" ]]; then
        tmux display-message "Error: Directory creation failed for $target_dir"
        exit 1
    fi

    tmux new-session -d -s "$session_name" -c "$target_dir" -n "nvim"
    tmux new-window -t "$session_name" -c "$target_dir" -n "git"
    tmux new-window -t "$session_name" -c "$target_dir" -n "nx"
    tmux select-window -t "$session_name:nvim"
fi

[[ -n "$TMUX" ]] && tmux switch-client -t "$session_name" || tmux attach-session -t "$session_name"
