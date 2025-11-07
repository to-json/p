#!/usr/bin/env zsh

p() {
  local cmd="${1:-}"

  if [[ -z "$cmd" ]]; then
    echo "Usage: p <new|cd|done|goto> [args...]" >&2
    return 1
  fi

  shift

  case "$cmd" in
    new)
      wt-new "$@"
      ;;
    cd)
      wt-cd "$@"
      ;;
    done)
      wt-done "$@"
      ;;
    goto|g)
      wt-goto "$@"
      ;;
    *)
      echo "Error: Unknown command '$cmd'" >&2
      echo "Available: new, cd, done, goto (g)" >&2
      return 1
      ;;
  esac
}
