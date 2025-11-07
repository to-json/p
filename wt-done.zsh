#!/usr/bin/env zsh

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

  echo "Removing worktree: $current_worktree"
  cd "$main_worktree"
  git worktree remove "$current_worktree"
}
