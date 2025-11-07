#!/usr/bin/env zsh

readonly WT_GOTO_PARENTS=(
  "$HOME/code"
  "$HOME/hc"
  "$HOME/scripts"
)

wt-goto() {
  local -a choices paths
  local -A path_map

  for parent in "${WT_GOTO_PARENTS[@]}"; do
    [[ -d "$parent" ]] || continue

    for repo in "$parent"/*(/N); do
      local repo_name=${repo:t}
      [[ "$repo_name" == *.* ]] && continue

      choices+=("$repo_name")
      path_map["$repo_name"]="$repo"

      for worktree in "$parent/$repo_name".*(/N); do
        local tree_name=${worktree:t}
        choices+=("$tree_name")
        path_map["$tree_name"]="$worktree"
      done
    done
  done

  if [[ ${#choices} -eq 0 ]]; then
    echo "Error: No repositories found" >&2
    return 1
  fi

  local selected=$(printf '%s\n' "${choices[@]}" | gum choose --height 15)

  if [[ -z "$selected" ]]; then
    return 0
  fi

  cd "${path_map[$selected]}"
}
