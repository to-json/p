#!/usr/bin/env zsh

# Domain Glossary
#
# Core Concepts:
#   repo_name       - Name of the git repository (e.g., "myproject")
#   repo_path       - Absolute path to the main repository (e.g., "/Users/me/code/myproject")
#   repo_parent     - Directory containing repositories (e.g., "/Users/me/code")
#   branch_name     - Git branch name (e.g., "jae/feature-work")
#   worktree_suffix - Filesystem-safe identifier for worktree (e.g., "jae-feature-work")
#   worktree_path   - Absolute path to worktree (e.g., "/Users/me/code/myproject.jae-feature-work")
#   main_worktree   - The original repository checkout (without .suffix)
#
# Naming Convention:
#   Main repo:      {repo_parent}/{repo_name}
#   Worktrees:      {repo_parent}/{repo_name}.{worktree_suffix}
#

WT_REPO_PARENTS=(
  "$HOME/code"
  "$HOME/hc"
  "$HOME/scripts"
)

WT_REMOTE_PROJECTS=(
  infra
  hound
)

WT_DEFAULT_REMOTE="origin"

WT_BRANCH_PREFIX_TEMPLATE='$(_wt_get_username)/'

_wt_get_repo_root() {
  local repo_root=$(git rev-parse --show-toplevel 2>/dev/null)
  if [[ -z "$repo_root" ]]; then
    echo "Error: Not in a git repository" >&2
    return 1
  fi
  echo "$repo_root"
}

_wt_validate_repo_parent() {
  local parent_path="$1"
  for valid_parent in "${WT_REPO_PARENTS[@]}"; do
    if [[ "$parent_path" == "$valid_parent" ]]; then
      return 0
    fi
  done
  echo "Error: Repository must be in one of: ${(j:, :)WT_REPO_PARENTS[@]}" >&2
  return 1
}

_wt_build_worktree_path() {
  local repo_parent="$1"
  local repo_name="$2"
  local suffix="$3"
  echo "$repo_parent/$repo_name.$suffix"
}

_wt_ensure_path_available() {
  local worktree_path="$1"
  if [[ -e "$worktree_path" ]]; then
    echo "Error: Path already exists: $worktree_path" >&2
    return 1
  fi
}

_wt_display_worktree_info() {
  local branch="$1"
  local worktree_path="$2"
  local action="${3:-Creating}"
  echo "$action worktree:"
  echo "  Branch: $branch"
  echo "  Path: $worktree_path"
}

_wt_get_username() {
  whoami | tr '[:upper:] ' '[:lower:]-'
}

_wt_sanitize_branch_name() {
  local branch_name="$1"
  echo "${branch_name//\//-}"
}

_wt_has_gum() {
  command -v gum >/dev/null 2>&1
}

_wt_confirm() {
  local prompt="$1"
  if _wt_has_gum; then
    gum confirm "$prompt"
  else
    echo -n "$prompt [y/N] " >&2
    read -q
  fi
}

_wt_filter() {
  if _wt_has_gum; then
    gum filter
  else
    echo "Error: gum not found. Install with: brew install gum" >&2
    return 1
  fi
}

_wt_get_main_worktree() {
  local worktree_path="${1:-.}"
  git -C "$worktree_path" rev-parse --path-format=absolute --git-common-dir 2>/dev/null | sed 's:/\.git$::'
}

_wt_branch_exists_locally() {
  local branch_name="$1"
  local repo_path="${2:-.}"
  git -C "$repo_path" rev-parse --verify "$branch_name" >/dev/null 2>&1
}

_wt_branch_exists_on_remote() {
  local branch_name="$1"
  local repo_path="${2:-.}"
  local remote_check=$(git -C "$repo_path" ls-remote --heads "$WT_DEFAULT_REMOTE" "$branch_name" 2>/dev/null)
  [[ -n "$remote_check" ]]
}

_wt_create_and_enter_worktree() {
  local branch_name="$1"
  local worktree_path="$2"
  local action="${3:-Creating}"
  local create_branch="${4:-}"

  _wt_ensure_path_available "$worktree_path" || return 1
  _wt_display_worktree_info "$branch_name" "$worktree_path" "$action"

  if [[ -n "$create_branch" ]]; then
    git worktree add -b "$branch_name" "$worktree_path" || {
      echo "Error: Failed to create worktree" >&2
      return 1
    }
  else
    git worktree add "$worktree_path" "$branch_name" || {
      echo "Error: Failed to create worktree" >&2
      return 1
    }
  fi

  cd "$worktree_path" || return 1
}

_wt_validate_array_selection() {
  local choices_name=$1
  local values_name=$2
  local selected="$3"

  # Use nameref to access arrays in caller's scope
  local -a choices=("${(@P)choices_name}")
  local -a values=("${(@P)values_name}")

  local index=${choices[(ie)$selected]}
  if (( index > ${#choices} )); then
    echo "Error: Selection not found" >&2
    return 1
  fi

  local value="${values[$index]}"
  if [[ -z "$value" ]]; then
    echo "Error: Invalid selection (empty entry)" >&2
    return 1
  fi

  echo "$index"
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

_wt_list_worktree_suffixes() {
  local repo_name="$1"
  local repo_parent=$(_wt_find_repo_parent "$repo_name") || return 1

  local -a suffixes
  for worktree_path in "$repo_parent/$repo_name".*(/N); do
    local worktree_suffix=${worktree_path:t}
    worktree_suffix=${worktree_suffix#$repo_name.}
    suffixes+=("$worktree_suffix")
  done
  printf '%s\n' "${suffixes[@]}"
}

_wt_list_local_branches() {
  git branch --format='%(refname:short)' 2>/dev/null
}

_wt_list_local_branches_in() {
  local repo_path="$1"
  git -C "$repo_path" branch --format='%(refname:short)' 2>/dev/null
}

_wt_list_remote_branches() {
  _wt_list_remote_branches_in "."
}

_wt_list_remote_branches_in() {
  local repo_path="${1:-.}"
  local -a local_branches remote_branches
  local_branches=(${(f)"$(git -C "$repo_path" branch --format='%(refname:short)' 2>/dev/null)"})
  remote_branches=(${(f)"$(git -C "$repo_path" branch --remotes --format='%(refname:short)' 2>/dev/null)"})

  for branch in "${remote_branches[@]}"; do
    local short_branch="${branch#$WT_DEFAULT_REMOTE/}"
    [[ "$short_branch" == "HEAD" ]] && continue
    (( ${local_branches[(Ie)$short_branch]} )) && continue
    echo "$short_branch"
  done
}

_wt_list_all_branches() {
  _wt_list_local_branches
  _wt_list_remote_branches
}

_wt_get_existing_worktrees() {
  for parent in "${WT_REPO_PARENTS[@]}"; do
    [[ -d "$parent" ]] || continue

    for repo in "$parent"/*(/N); do
      local repo_name=${repo:t}
      [[ "$repo_name" == *.* ]] && continue

      if [[ -d "$repo/.git" ]]; then
        local branch=$(git -C "$repo" rev-parse --abbrev-ref HEAD 2>/dev/null)
        [[ -n "$branch" ]] && echo "$repo_name:$branch|$repo"
      fi

      for worktree_path in "$parent/$repo_name".*(/N); do
        if [[ -d "$worktree_path/.git" ]]; then
          local branch=$(git -C "$worktree_path" rev-parse --abbrev-ref HEAD 2>/dev/null)
          [[ -n "$branch" ]] && echo "$repo_name:$branch|$worktree_path"
        fi
      done
    done
  done
}

# Public Commands

wt-new() {
  local title="${1:-}"

  if [[ -z "$title" ]]; then
    echo "Usage: wt-new <Title>" >&2
    return 1
  fi

  local repo_root=$(_wt_get_repo_root) || return 1
  local repo_name=$(basename "$repo_root")
  local repo_parent=$(dirname "$repo_root")

  _wt_validate_repo_parent "$repo_parent" || return 1

  local branch_prefix=$(eval echo "$WT_BRANCH_PREFIX_TEMPLATE")
  local branch_name="${branch_prefix}${title}"
  local worktree_suffix=$(_wt_sanitize_branch_name "$title")
  local worktree_path=$(_wt_build_worktree_path "$repo_parent" "$repo_name" "$worktree_suffix")

  _wt_create_and_enter_worktree "$branch_name" "$worktree_path" "Creating" "yes"
}

wt-checkout() {
  local branch_name="${1:-}"

  if [[ -z "$branch_name" ]]; then
    echo "Usage: wt-checkout <branch>" >&2
    return 1
  fi

  local repo_root=$(_wt_get_repo_root) || return 1
  local repo_name=$(basename "$repo_root")
  local repo_parent=$(dirname "$repo_root")

  if ! _wt_branch_exists_locally "$branch_name"; then
    if ! _wt_branch_exists_on_remote "$branch_name"; then
      echo "Error: Branch '$branch_name' does not exist locally or on remote" >&2
      return 1
    fi
  fi

  _wt_validate_repo_parent "$repo_parent" || return 1

  local worktree_suffix=$(_wt_sanitize_branch_name "$branch_name")
  local worktree_path=$(_wt_build_worktree_path "$repo_parent" "$repo_name" "$worktree_suffix")

  _wt_create_and_enter_worktree "$branch_name" "$worktree_path" "Checking out"
}

wt-cd() {
  local repo_name="${1:-}"
  local worktree_suffix="${2:-}"

  if [[ -z "$repo_name" ]]; then
    echo "Usage: wt-cd <repo> [tree]" >&2
    return 1
  fi

  local found_path=$(_wt_find_repo "$repo_name")
  if [[ -z "$found_path" ]]; then
    echo "Error: Repository '$repo_name' not found" >&2
    return 1
  fi

  if [[ -z "$worktree_suffix" ]]; then
    cd "$found_path" || return 1
  else
    local worktree_path=$(_wt_build_worktree_path "$(dirname "$found_path")" "$repo_name" "$worktree_suffix")
    if [[ ! -d "$worktree_path" ]]; then
      echo "Error: Worktree '$worktree_path' not found" >&2
      return 1
    fi
    cd "$worktree_path" || return 1
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

  local upstream=$(git rev-parse --abbrev-ref @{u} 2>/dev/null)
  if [[ -n "$upstream" ]]; then
    local unpushed=$(git rev-list @{u}..HEAD --count 2>/dev/null)
    if [[ -n "$unpushed" && "$unpushed" -gt 0 ]]; then
      echo "Warning: Branch has $unpushed unpushed commit(s)" >&2
      if ! _wt_confirm "Remove worktree anyway?"; then
        echo "Cancelled" >&2
        return 1
      fi
    fi
  fi

  echo "Removing worktree: $current_worktree"
  echo "Deleting branch: $branch_name"

  cd "$main_worktree" || return 1

  git worktree remove "$current_worktree" || {
    echo "Error: Failed to remove worktree" >&2
    return 1
  }

  # Try safe delete first, fall back to force delete if unmerged
  if ! git branch -d "$branch_name" 2>/dev/null; then
    echo "Branch is not fully merged" >&2
    if _wt_confirm "Force delete branch '$branch_name'?"; then
      git branch -D "$branch_name" || {
        echo "Warning: Failed to delete branch '$branch_name'" >&2
      }
    else
      echo "Branch '$branch_name' preserved" >&2
    fi
  fi
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

      for worktree_path in "$parent/$repo_name".*(/N); do
        local worktree_suffix=${worktree_path:t}
        choices+=("$worktree_suffix ($parent_name)")
        paths+=("$worktree_path")
      done
    done
  done

  if [[ ${#choices} -eq 0 ]]; then
    echo "Error: No repositories found" >&2
    return 1
  fi

  local selected=$(printf '%s\n' "${choices[@]}" | _wt_filter)

  if [[ -z "$selected" ]]; then
    return 0
  fi

  local index
  index=$(_wt_validate_array_selection choices paths "$selected") || return 1
  cd "${paths[$index]}" || return 1
}

wt-use() {
  local -a choices values repos fetchable_repos
  for repo_name in "${WT_REMOTE_PROJECTS[@]}"; do
    local repo_path=$(_wt_find_repo "$repo_name")
    [[ -n "$repo_path" ]] && fetchable_repos+=("$repo_name")
  done

  if [[ ${#fetchable_repos[@]} -gt 0 ]]; then
    if _wt_confirm "Fetch remotes for ${(j:, :)fetchable_repos} to get latest branches?"; then
      for repo_name in "${fetchable_repos[@]}"; do
        local repo_path=$(_wt_find_repo "$repo_name")
        echo "Fetching $repo_name..." >&2
        git -C "$repo_path" fetch "$WT_DEFAULT_REMOTE" --quiet || {
          echo "Warning: Failed to fetch $repo_name" >&2
        }
      done
    fi
  fi

  repos=(${(f)"$(_wt_list_all_repos)"})

  local -A worktree_map

  while IFS='|' read -r key targetpath; do
    worktree_map[$key]=$targetpath
    choices+=("$key [active]")
    values+=("$key|active|$targetpath")
  done < <(_wt_get_existing_worktrees)

  for repo_name in "${repos[@]}"; do
    local repo_path=$(_wt_find_repo "$repo_name")
    [[ -z "$repo_path" ]] && continue

    local -a branches
    branches=(${(f)"$(_wt_list_local_branches_in "$repo_path")"})

    for branch in "${branches[@]}"; do
      local key="$repo_name:$branch"
      if [[ -z "${worktree_map[$key]}" ]]; then
        choices+=("$key")
        values+=("$key|checkout|$repo_path")
      fi
    done

    if (( ${WT_REMOTE_PROJECTS[(Ie)$repo_name]} )); then
      local -a remote_branches
      remote_branches=(${(f)"$(_wt_list_remote_branches_in "$repo_path")"})

      for branch in "${remote_branches[@]}"; do
        local key="$repo_name:$branch"
        if [[ -z "${worktree_map[$key]}" ]]; then
          choices+=("$key [remote]")
          values+=("$key|checkout|$repo_path")
        fi
      done
    fi
  done

  if [[ ${#choices} -eq 0 ]]; then
    echo "Error: No branches found" >&2
    return 1
  fi

  local selected=$(printf '%s\n' "${choices[@]}" | _wt_filter)
  [[ -z "$selected" ]] && return 0

  local index
  index=$(_wt_validate_array_selection choices values "$selected") || return 1

  local value="${values[$index]}"
  local key="${value%%|*}"
  local action="${${value#*|}%%|*}"
  local outpath="${value##*|}"
  local branch="${key#*:}"

  if [[ "$action" == "active" ]]; then
    cd "$outpath" || return 1
  else
    cd "$outpath" || return 1
    wt-checkout "$branch"
  fi
}

# Completion Functions

_wt-checkout() {
  local -a branches
  branches=(${(f)"$(_wt_list_all_branches)"})
  _describe 'branch' branches
}

_wt-cd() {
  local -a repos suffixes

  case $CURRENT in
    2)
      repos=(${(f)"$(_wt_list_all_repos)"})
      _describe -t repositories 'repository' repos
      ;;

    3)
      local repo_name=$words[2]
      suffixes=(${(f)"$(_wt_list_worktree_suffixes "$repo_name" 2>/dev/null)"})
      [[ ${#suffixes} -gt 0 ]] && _describe -t worktrees 'worktree' suffixes
      ;;
  esac
}

if (( $+functions[compdef] )); then
  compdef _wt-checkout wt-checkout
  compdef _wt-cd wt-cd
fi
