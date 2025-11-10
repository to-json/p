#!/usr/bin/env zsh

WT_REPO_PARENTS=(
  "$HOME/code"
  "$HOME/hc"
  "$HOME/scripts"
)

_wt_get_repo_root() {
  local repo_root=$(git rev-parse --show-toplevel 2>/dev/null)
  if [[ -z "$repo_root" ]]; then
    echo "Error: Not in a git repository" >&2
    return 1
  fi
  echo "$repo_root"
}

_wt_get_repo_info() {
  local repo_root=$(_wt_get_repo_root) || return 1
  local -A info
  info[root]=$repo_root
  info[name]=$(basename "$repo_root")
  info[parent]=$(dirname "$repo_root")
  info[parent_name]=$(basename "${info[parent]}")

  for key val in ${(kv)info}; do
    echo "$key=$val"
  done
}

_wt_validate_repo_parent() {
  local parent_name="$1"
  for parent in code hc scripts; do
    if [[ "$parent_name" == "$parent" ]]; then
      return 0
    fi
  done
  echo "Error: Repository must be in one of: code, hc, scripts" >&2
  return 1
}

_wt_build_worktree_path() {
  local repo_parent="$1"
  local repo_name="$2"
  local suffix="$3"
  echo "$repo_parent/$repo_name.$suffix"
}

_wt_ensure_path_available() {
  local path="$1"
  if [[ -e "$path" ]]; then
    echo "Error: Path already exists: $path" >&2
    return 1
  fi
}

_wt_display_worktree_info() {
  local branch="$1"
  local path="$2"
  local action="${3:-Creating}"
  echo "$action worktree:"
  echo "  Branch: $branch"
  echo "  Path: $path"
}

_wt_get_username() {
  whoami | tr '[:upper:] ' '[:lower:]-'
}

_wt_find_repo() {
  local repo_name="$1"
  for parent in "${WT_REPO_PARENTS[@]}"; do
    if [[ -d "$parent/$repo_name" ]]; then
      echo "$parent/$repo_name"
      return 0
    fi
  done
  return 1
}

_wt_list_all_repos() {
  local -a repos
  for parent in "${WT_REPO_PARENTS[@]}"; do
    [[ -d "$parent" ]] || continue
    for repo in "$parent"/*(/N); do
      local name=${repo:t}
      [[ "$name" == *.* ]] && continue
      repos+=("$name")
    done
  done
  printf '%s\n' "${repos[@]}"
}

_wt_find_repo_parent() {
  local repo_name="$1"
  for parent in "${WT_REPO_PARENTS[@]}"; do
    if [[ -d "$parent/$repo_name" ]]; then
      echo "$parent"
      return 0
    fi
  done
  return 1
}

_wt_list_worktrees() {
  local repo_name="$1"
  local repo_parent=$(_wt_find_repo_parent "$repo_name") || return 1

  local -a trees
  for worktree in "$repo_parent/$repo_name".*(/N); do
    local tree_name=${worktree:t}
    tree_name=${tree_name#$repo_name.}
    trees+=("$tree_name")
  done
  printf '%s\n' "${trees[@]}"
}

_wt_list_local_branches() {
  git branch --format='%(refname:short)' 2>/dev/null
}

_wt_list_remote_branches() {
  local -a local_branches remote_branches
  local_branches=(${(f)"$(_wt_list_local_branches)"})

  # Get remote branches and strip remotes/origin/ prefix
  git branch --remotes --format='%(refname:short)' 2>/dev/null | while read -r branch; do
    # Strip remotes/origin/ prefix
    local short_branch="${branch#remotes/origin/}"
    # Skip HEAD pointer
    [[ "$short_branch" == "HEAD" ]] && continue
    # Skip if this branch exists locally
    (( ${local_branches[(Ie)$short_branch]} )) && continue
    echo "$short_branch"
  done
}

_wt_list_all_branches() {
  _wt_list_local_branches
  _wt_list_remote_branches
}

# ============================================================================
# Public Commands
# ============================================================================

wt-new() {
  local title="${1:-}"

  if [[ -z "$title" ]]; then
    echo "Usage: wt-new <Title>" >&2
    return 1
  fi

  local -A info
  while IFS='=' read -r key val; do
    info[$key]=$val
  done < <(_wt_get_repo_info) || return 1

  _wt_validate_repo_parent "${info[parent_name]}" || return 1

  local username=$(_wt_get_username)
  local branch_name="$username/$title"
  local worktree_path=$(_wt_build_worktree_path "${info[parent]}" "${info[name]}" "$title")

  _wt_ensure_path_available "$worktree_path" || return 1
  _wt_display_worktree_info "$branch_name" "$worktree_path" "Creating"

  git worktree add -b "$branch_name" "$worktree_path"
  cd "$worktree_path"
}

wt-checkout() {
  local branch_name="${1:-}"

  if [[ -z "$branch_name" ]]; then
    echo "Usage: wt-checkout <branch>" >&2
    return 1
  fi

  local -A info
  while IFS='=' read -r key val; do
    info[$key]=$val
  done < <(_wt_get_repo_info) || return 1

  # Verify the branch exists (locally or remotely)
  if ! git rev-parse --verify "$branch_name" >/dev/null 2>&1; then
    # Try checking remote branches as fallback
    local remote_check=$(git ls-remote --heads origin "$branch_name" 2>/dev/null)
    if [[ -z "$remote_check" ]]; then
      echo "Error: Branch '$branch_name' does not exist locally or on remote" >&2
      return 1
    fi
  fi

  _wt_validate_repo_parent "${info[parent_name]}" || return 1

  # Replace '/' with '-' in branch name for the path
  local path_name="${branch_name//\//-}"
  local worktree_path=$(_wt_build_worktree_path "${info[parent]}" "${info[name]}" "$path_name")

  _wt_ensure_path_available "$worktree_path" || return 1
  _wt_display_worktree_info "$branch_name" "$worktree_path" "Checking out"

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

  local found_path=$(_wt_find_repo "$repo_name")
  if [[ -z "$found_path" ]]; then
    echo "Error: Repository '$repo_name' not found" >&2
    return 1
  fi

  if [[ -z "$tree_name" ]]; then
    cd "$found_path"
  else
    local worktree_path=$(_wt_build_worktree_path "$(dirname "$found_path")" "$repo_name" "$tree_name")
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

_wt-checkout() {
  local -a branches
  branches=(${(f)"$(_wt_list_all_branches)"})
  _describe 'branch' branches
}

_wt-cd() {
  local -a repos trees

  case $CURRENT in
    2)
      repos=(${(f)"$(_wt_list_all_repos)"})
      _describe -t repositories 'repository' repos
      ;;

    3)
      local repo_name=$words[2]
      trees=(${(f)"$(_wt_list_worktrees "$repo_name" 2>/dev/null)"})
      [[ ${#trees} -gt 0 ]] && _describe -t worktrees 'worktree' trees
      ;;
  esac
}

# Only register completions if compdef is available (interactive shell with completion system)
if (( $+functions[compdef] )); then
  compdef _wt-checkout wt-checkout
  compdef _wt-cd wt-cd
fi
