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
typeset -A pr_map
# Use TAB as a safe, invisible delimiter
TAB=$'\t'

# --- STEP 2.5: Bulk Fetch PRs ---
if command -v gh >/dev/null; then
    while read -r num branch_name; do
        pr_map[$branch_name]=$num
    done < <(gh pr list --state open --limit 300 --json number,headRefName -q '.[] | "\(.number) \(.headRefName)"' 2>/dev/null)
fi

# --- PART A: Existing Worktrees ---
while read -r line; do
    if [[ $line == worktree* ]]; then
        current_path="${line#worktree }"
    elif [[ $line == branch* ]]; then
        full_branch="${line#branch refs/heads/}"
        seen_branches[$full_branch]=1
        
        safe_branch=${full_branch//\//-}
        safe_branch=${safe_branch//./-}
        session_name="$REPO_NAME-$safe_branch"
        
        if tmux has-session -t "$session_name" 2>/dev/null; then
            state="●"
            boost=20000000000
        else
            state="○"
            boost=10000000000
        fi
        
        # PR Indicator
        pr_icon=""
        pr_num="${pr_map[$full_branch]}"
        if [[ -n "$pr_num" ]]; then
            pr_icon=" $(tput setaf 6)[PR #${pr_num}]$(tput sgr0)"
        fi

        ts=$(git log -1 --format="%ct" "$full_branch" 2>/dev/null)
        [[ -z "$ts" ]] && ts=0
        (( ts += boost ))
        
        # Structure: TS <TAB> VISUAL <TAB> BRANCH <TAB> PATH <TAB> REF
        # We put the PR icon right after the branch name in the visual column (2)
        raw_list+=("${ts}${TAB}${state} | ${full_branch}${pr_icon}${TAB}${full_branch}${TAB}${current_path}${TAB}${full_branch}")
    fi
done < <(git worktree list --porcelain)

# --- PART B: New Branches ---
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
    
    # PR Indicator
    pr_icon=""
    pr_num="${pr_map[$clean]}"
    if [[ -n "$pr_num" ]]; then
        pr_icon=" $(tput setaf 6)[PR #${pr_num}]$(tput sgr0)"
    fi

    raw_list+=("${ts}${TAB}+ | ${clean}${pr_icon}${TAB}${clean}${TAB}CREATE_NEEDED${TAB}${ref}")

done < <(git for-each-ref --sort=-committerdate --format='%(committerdate:unix)|%(refname)' refs/heads refs/remotes/origin)

# 3. FZF Selection
PREVIEW_CMD="git log -30 --color=always --graph --format='%C(yellow)%h%C(reset) %C(green)(%ar)%C(reset) %C(blue)<%an>%C(reset) %s' {5} 2>/dev/null"

selected=$(print -l "${raw_list[@]}" | sort -rn | fzf --ansi \
    --delimiter "$TAB" \
    --with-nth 2 \
    --header 'ENTER: Switch | CTRL-X: Kill | CTRL-D: Delete | CTRL-O: Open PR & Switch' \
    --preview "$PREVIEW_CMD" \
    --preview-window 'down:60%:wrap' \
    --reverse \
    --expect=ctrl-x,ctrl-d,ctrl-o)

[[ -z "$selected" ]] && exit 0

# Parse Selection
lines=("${(@f)selected}")
key=${lines[1]}
item=${lines[2]}

[[ -z "$item" ]] && exit 0

# Extract Data using Zsh Split
# We split the line by TAB to get the raw data fields back
parts=("${(@s/	/)item}") # Literal Tab split

# Fallback: If literal tab fails (e.g. copy-paste issues), try variable split
if [[ ${#parts} -lt 4 ]]; then
    parts=("${(@s/$TAB/)item}")
fi

# Corrected Indices:
# 1 = Timestamp
# 2 = Visual String
# 3 = Clean Branch Name
# 4 = Target Path / CREATE_NEEDED
branch="${parts[3]}"
target_dir="${parts[4]}"

# Trim whitespace (Safety)
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
elif [[ "$key" == "ctrl-o" ]]; then
    tmux display-message "Opening PR and Switching..."
    tmux run-shell -b "export PATH=$PATH; cd '$MAIN_REPO_PATH' && gh pr view '$branch' --web"
    # No exit: Fall through to create session
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
if [[ -z "$target_dir" || "$target_dir" == "/" ]]; then
    tmux display-message "Error: Invalid target directory."
    exit 1
fi

if ! tmux has-session -t "$session_name" 2>/dev/null; then
    count=0
    while [[ ! -d "$target_dir" && $count -lt 20 ]]; do
        sleep 0.1
        ((count++))
    done
    
    if [[ ! -d "$target_dir" ]]; then
        tmux display-message "Error: Directory creation failed: $target_dir"
        read -k 1
        exit 1
    fi

    tmux new-session -d -s "$session_name" -c "$target_dir" -n "nvim"
    tmux new-window -t "$session_name" -c "$target_dir" -n "git"
    tmux new-window -t "$session_name" -c "$target_dir" -n "nx"
    tmux select-window -t "$session_name:nvim"
fi

# 7. Switch
if [[ -n "$TMUX" ]]; then
    tmux switch-client -t "$session_name"
else
    tmux attach-session -t "$session_name"
fi
