#!/usr/bin/env zsh

readonly WT_REPO_PARENTS=(
  "$HOME/code"
  "$HOME/hc"
  "$HOME/scripts"
)

wt-new() {
  local title="${1:-}"

  if [[ -z "$title" ]]; then
    echo "Usage: wt-new <Title>" >&2
    return 1
  fi

  local repo_root=$(git rev-parse --show-toplevel 2>/dev/null)
  if [[ -z "$repo_root" ]]; then
    echo "Error: Not in a git repository" >&2
    return 1
  fi

  local repo_name=$(basename "$repo_root")
  local repo_parent=$(dirname "$repo_root")
  local parent_name=$(basename "$repo_parent")

  local valid_parent=false
  for parent in code hc scripts; do
    if [[ "$parent_name" == "$parent" ]]; then
      valid_parent=true
      break
    fi
  done

  if [[ "$valid_parent" == false ]]; then
    echo "Error: Repository must be in one of: code, hc, scripts" >&2
    return 1
  fi

  local username=$(whoami | tr '[:upper:] ' '[:lower:]-')
  local branch_name="$username/$title"
  local worktree_path="$repo_parent/$repo_name.$title"

  if [[ -e "$worktree_path" ]]; then
    echo "Error: Path already exists: $worktree_path" >&2
    return 1
  fi

  echo "Creating worktree:"
  echo "  Branch: $branch_name"
  echo "  Path: $worktree_path"

  git worktree add -b "$branch_name" "$worktree_path"
  cd "$worktree_path"
}

wt-checkout() {
  local branch_name="${1:-}"

  if [[ -z "$branch_name" ]]; then
    echo "Usage: wt-checkout <branch>" >&2
    return 1
  fi

  local repo_root=$(git rev-parse --show-toplevel 2>/dev/null)
  if [[ -z "$repo_root" ]]; then
    echo "Error: Not in a git repository" >&2
    return 1
  fi

  # Verify the branch exists (locally or remotely)
  if ! git rev-parse --verify "$branch_name" >/dev/null 2>&1; then
    # Try checking remote branches as fallback
    local remote_check=$(git ls-remote --heads origin "$branch_name" 2>/dev/null)
    if [[ -z "$remote_check" ]]; then
      echo "Error: Branch '$branch_name' does not exist locally or on remote" >&2
      return 1
    fi
  fi

  local repo_name=$(basename "$repo_root")
  local repo_parent=$(dirname "$repo_root")
  local parent_name=$(basename "$repo_parent")

  local valid_parent=false
  for parent in code hc scripts; do
    if [[ "$parent_name" == "$parent" ]]; then
      valid_parent=true
      break
    fi
  done

  if [[ "$valid_parent" == false ]]; then
    echo "Error: Repository must be in one of: code, hc, scripts" >&2
    return 1
  fi

  # Replace '/' with '>' in branch name for the path
  local path_name="${branch_name//\//-}"
  local worktree_path="$repo_parent/$repo_name.$path_name"

  if [[ -e "$worktree_path" ]]; then
    echo "Error: Path already exists: $worktree_path" >&2
    return 1
  fi

  echo "Checking out worktree:"
  echo "  Branch: $branch_name"
  echo "  Path: $worktree_path"

  git worktree add "$worktree_path" "$branch_name"
  cd "$worktree_path"
}

wt-cd() {
  local repo_name="${1:-}"
  local tree_name="${2:-}"

  if [[ -z "$repo_name" ]]; then
    echo "Usage: wt-cd <repo> [tree]" >&2
    return 1
  fi

  local found_path=""
  for parent in "${WT_REPO_PARENTS[@]}"; do
    if [[ -d "$parent/$repo_name" ]]; then
      found_path="$parent/$repo_name"
      break
    fi
  done

  if [[ -z "$found_path" ]]; then
    echo "Error: Repository '$repo_name' not found" >&2
    return 1
  fi

  if [[ -z "$tree_name" ]]; then
    cd "$found_path"
  else
    local worktree_path="$(dirname "$found_path")/$repo_name.$tree_name"
    if [[ ! -d "$worktree_path" ]]; then
      echo "Error: Worktree '$worktree_path' not found" >&2
      return 1
    fi
    cd "$worktree_path"
  fi
}

wt-done() {
  local current_worktree=$(git rev-parse --show-toplevel 2>/dev/null)
  if [[ -z "$current_worktree" ]]; then
    echo "Error: Not in a git repository" >&2
    return 1
  fi

  local main_worktree=$(git rev-parse --path-format=absolute --git-common-dir | sed 's:/\.git$::')

  if [[ "$current_worktree" == "$main_worktree" ]]; then
    echo "Error: Cannot remove main worktree" >&2
    return 1
  fi

  local branch_name=$(git rev-parse --abbrev-ref HEAD)

  echo "Removing worktree: $current_worktree"
  echo "Deleting branch: $branch_name"

  cd "$main_worktree"
  git worktree remove "$current_worktree"
  git branch -D "$branch_name"
}

wt-goto() {
  local -a choices paths

  for parent in "${WT_REPO_PARENTS[@]}"; do
    [[ -d "$parent" ]] || continue
    local parent_name=${parent:t}

    for repo in "$parent"/*(/N); do
      local repo_name=${repo:t}
      [[ "$repo_name" == *.* ]] && continue

      choices+=("$repo_name ($parent_name)")
      paths+=("$repo")

      for worktree in "$parent/$repo_name".*(/N); do
        local tree_name=${worktree:t}
        choices+=("$tree_name ($parent_name)")
        paths+=("$worktree")
      done
    done
  done

  if [[ ${#choices} -eq 0 ]]; then
    echo "Error: No repositories found" >&2
    return 1
  fi

  local selected=$(printf '%s\n' "${choices[@]}" | gum filter)

  if [[ -z "$selected" ]]; then
    return 0
  fi

  local index=${choices[(ie)$selected]}

  if (( index > ${#choices} )); then
    echo "Error: Selection not found" >&2
    return 1
  fi

  cd "${paths[$index]}"
}

# Completion for wt-checkout
_wt-checkout() {
  local -a branches
  branches=(${(f)"$(git branch --all --format='%(refname:short)' 2>/dev/null)"})
  _describe 'branch' branches
}

compdef _wt-checkout wt-checkout
