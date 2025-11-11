#!/usr/bin/env zsh

# Source worktree functions
source "$HOME/scripts/git/worktree.zsh"

p() {
  local cmd="${1:-}"

  if [[ -z "$cmd" ]]; then
    echo "Usage: p <(n)ew|g(e)t|(c)d|(d)one|(g)oto|(u)se> [args...]" >&2
    return 1
  fi

  shift

  case "$cmd" in
    new|n)
      wt-new "$@"
      ;;
    get|e)
      wt-checkout "$@"
      ;;
    cd|c)
      wt-cd "$@"
      ;;
    done|d)
      wt-done "$@"
      ;;
    goto|g)
      wt-goto "$@"
      ;;
    use|u)
      wt-use "$@"
      ;;
    *)
      echo "Error: Unknown command '$cmd'" >&2
      echo "Available: (n)ew, g(e)t, (c)d, (d)one, (g)oto, (u)se" >&2
      return 1
      ;;
  esac
}
