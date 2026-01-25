#!/bin/zsh
# -----------------------------------------------------------------------------
# wm.sh - Worktree Manager (Ultra-Minimalist Naming)
# -----------------------------------------------------------------------------
export PATH=$PATH:/usr/local/bin:/usr/bin:/bin:/opt/homebrew/bin:/opt/homebrew/sbin

# 1. Resolve Script Path
SCRIPT_PATH=${0:a}

# 2. Project Validation
COMMON_DIR=$(git rev-parse --git-common-dir 2>/dev/null)
if [[ -z "$COMMON_DIR" ]]; then
    if [[ "$1" != --gen* ]]; then
        echo "Error: Not a git repository."
        echo "Navigate to a git project and try again."
        read -k 1 "REPLY?Press any key to exit..."
        exit 1
    fi
    exit 0
fi

MAIN_REPO_PATH=$(realpath "$COMMON_DIR/.." 2>/dev/null)
# We calculate REPO_NAME only for context, but we won't use it in the session name anymore
REPO_NAME=$(basename "$MAIN_REPO_PATH" 2>/dev/null | tr '.' '-')
PARENT_DIR=$(dirname "$MAIN_REPO_PATH" 2>/dev/null)
TAB=$'\t'

# =============================================================================
#  DATA GENERATOR
# =============================================================================
generate_data() {
    cd "$MAIN_REPO_PATH" || return 0
    setopt +o errexit 2>/dev/null

    local fetch_prs=$1
    local -a raw_list
    typeset -A seen_branches
    typeset -A pr_map

    # A. Fetch PRs
    if [[ "$fetch_prs" == "true" ]] && command -v gh >/dev/null; then
        while read -r num branch_name; do
            pr_map[$branch_name]=$num
        done < <(gh pr list --state open --limit 300 --json number,headRefName -q '.[] | "\(.number) \(.headRefName)"' 2>/dev/null || true)
    fi

    # B. Existing Worktrees
    while read -r line; do
        if [[ $line == worktree* ]]; then
            current_path="${line#worktree }"
        elif [[ $line == branch* ]]; then
            full_branch="${line#branch refs/heads/}"
            seen_branches[$full_branch]=1
            
            # LOGIC: Short Name (No Repo Prefix)
            short_branch="${full_branch##*feature/}"
            safe_branch=${short_branch//\//-}
            safe_branch=${safe_branch//./-}
            
            # FIX: Session name is JUST the branch part now
            session_name="$safe_branch"
            
            if tmux has-session -t "$session_name" 2>/dev/null; then
                state="●"
                boost=20000000000
            else
                state="○"
                boost=10000000000
            fi
            
            pr_icon=""
            pr_num="${pr_map[$full_branch]}"
            [[ -n "$pr_num" ]] && pr_icon=" $(tput setaf 6)[PR #${pr_num}]$(tput sgr0)"

            ts=$(git log -1 --format="%ct" "$full_branch" 2>/dev/null)
            [[ -z "$ts" ]] && ts=0
            (( ts += boost ))
            
            raw_list+=("${ts}${TAB}${state} | ${full_branch}${pr_icon}${TAB}${full_branch}${TAB}${current_path}${TAB}${full_branch}")
        fi
    done < <(git worktree list --porcelain 2>/dev/null)

    # C. New Branches
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
        
        pr_icon=""
        pr_num="${pr_map[$clean]}"
        [[ -n "$pr_num" ]] && pr_icon=" $(tput setaf 6)[PR #${pr_num}]$(tput sgr0)"

        raw_list+=("${ts}${TAB}+ | ${clean}${pr_icon}${TAB}${clean}${TAB}CREATE_NEEDED${TAB}${ref}")

    done < <(git for-each-ref --sort=-committerdate --format='%(committerdate:unix)|%(refname)' refs/heads refs/remotes/origin 2>/dev/null)

    # Output
    if [[ ${#raw_list} -gt 0 ]]; then
        print -l "${raw_list[@]}" | sort -rn
    fi
}

# =============================================================================
#  MODE: GENERATOR
# =============================================================================
if [[ "$1" == "--gen-full" ]]; then
    generate_data "true"
    exit 0
fi

# =============================================================================
#  MODE: UI RUNNER
# =============================================================================

# 1. Pre-calculate FAST data
INITIAL_LIST=$(generate_data "false")

# 2. Setup Commands
RELOAD_CMD="cd '$MAIN_REPO_PATH' && zsh '$SCRIPT_PATH' --gen-full 2>&1 || true"
PREVIEW_CMD="git log -30 --color=always --graph --format='%C(yellow)%h%C(reset) %C(green)(%ar)%C(reset) %C(blue)<%an>%C(reset) %s' {5} 2>/dev/null"

# 3. Run FZF
selected=$(echo "$INITIAL_LIST" | fzf --ansi \
    --delimiter "$TAB" \
    --with-nth 2 \
    --header 'ENTER: Switch | CTRL-O: Open PR | CTRL-X: Kill Session | CTRL-D: Delete Worktree' \
    --bind "start:reload:$RELOAD_CMD" \
    --preview "$PREVIEW_CMD" \
    --preview-window 'down:60%:wrap' \
    --reverse \
    --expect=ctrl-x,ctrl-d,ctrl-o)

if [[ -z "$selected" ]]; then
    tput init 2>/dev/null
    exit 0
fi

# 4. Parse Selection
lines=("${(@f)selected}")
key=${lines[1]}
item=${lines[2]}

if [[ -z "$item" ]]; then
    tput init 2>/dev/null
    exit 0
fi

parts=("${(@s/	/)item}")
if [[ ${#parts} -lt 4 ]]; then parts=("${(@s/$TAB/)item}"); fi

branch="${parts[3]}"
target_dir="${parts[4]}"

# Trim
branch="${branch#"${branch%%[![:space:]]*}"}"   
branch="${branch%"${branch##*[![:space:]]}"}"
target_dir="${target_dir#"${target_dir%%[![:space:]]*}"}"   
target_dir="${target_dir%"${target_dir##*[![:space:]]}"}"

# --- LOGIC: Short Name Generation ---
# 1. Strip everything up to and including 'feature/'
short_branch="${branch##*feature/}"
# 2. Sanitize for filename/session compatibility
safe_branch=${short_branch//\//-}
safe_branch=${safe_branch//./-}

# FIX: No Repo Prefix
session_name="$safe_branch"

# 5. Handle Actions
if [[ "$key" == "ctrl-x" ]]; then
    tmux kill-session -t "$session_name" 2>/dev/null
    tput init
    echo "Session killed: $session_name"
    exit 0
elif [[ "$key" == "ctrl-d" ]]; then
    [[ "$target_dir" == "$MAIN_REPO_PATH" ]] && echo "Cannot delete main repo." && exit 1
    tmux kill-session -t "$session_name" 2>/dev/null
    git worktree remove "$target_dir" --force
    tput init
    echo "Worktree deleted: $target_dir"
    exit 0
elif [[ "$key" == "ctrl-o" ]]; then
    tmux display-message "Opening PR and Switching..."
    tmux run-shell -b "export PATH=$PATH; cd '$MAIN_REPO_PATH' && gh pr view '$branch' --web"
fi

# 6. Create Logic
if [[ "$target_dir" == "CREATE_NEEDED" ]]; then
    # FIX: Create folder without Repo Prefix
    target_dir="$PARENT_DIR/$safe_branch"
    
    if [[ ! -d "$target_dir" ]]; then
        if git show-ref --verify --quiet "refs/heads/$branch"; then
            git worktree add "$target_dir" "$branch"
        else
            git worktree add -b "$branch" "$target_dir" "origin/$branch"
        fi
    fi
fi

# 7. Session Logic
if [[ -z "$target_dir" || "$target_dir" == "/" ]]; then
    echo "Error: Invalid target directory."
    exit 1
fi

if ! tmux has-session -t "$session_name" 2>/dev/null; then
    count=0
    while [[ ! -d "$target_dir" && $count -lt 20 ]]; do
        sleep 0.1
        ((count++))
    done
    
    if [[ ! -d "$target_dir" ]]; then
        echo "Error: Directory creation failed: $target_dir"
        read -k 1
        exit 1
    fi

    # --- SESSION STARTUP ---
    
    # Check for sub-folder structure and set global prefix
    if [[ -d "$target_dir/intl-depot" ]]; then
        CMD_PREFIX="cd intl-depot && "
    else
        CMD_PREFIX=""
    fi

    # 1. Create Session (Window 1: nvim)
    tmux new-session -d -s "$session_name" -c "$target_dir" -n "nvim"
    tmux send-keys -t "$session_name" "${CMD_PREFIX}nvim ." C-m

    # 2. Create Window (Window 2: git)
    tmux new-window -t "$session_name" -c "$target_dir" -n "git"
    tmux send-keys -t "$session_name" "${CMD_PREFIX}git status" C-m

    # 3. Create Window (Window 3: nx)
    tmux new-window -t "$session_name" -c "$target_dir" -n "nx"
    tmux send-keys -t "$session_name" "${CMD_PREFIX}npm i && npx nx run-many -t build" C-m

    # Focus back on nvim window
    tmux select-window -t "$session_name:nvim" 2>/dev/null || tmux select-window -t "$session_name:0"
fi

# 8. Switch
if [[ -n "$TMUX" ]]; then
    tmux switch-client -t "$session_name"
else
    tmux attach-session -t "$session_name" || read -k 1 "REPLY?Error attaching. Press any key to exit..."
fi
