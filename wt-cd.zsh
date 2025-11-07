#!/usr/bin/env zsh

readonly WT_REPO_PARENTS=(
  "$HOME/code"
  "$HOME/hc"
  "$HOME/scripts"
)

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
