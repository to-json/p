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
