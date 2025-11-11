#!/usr/bin/env zsh

# Source worktree functions
source "$HOME/scripts/git/worktree.zsh"

p-help() {
  cat <<'EOF'
Git Worktree Management Commands

p (n)ew <title>             Create new worktree with branch username/<title>
p (c)heckout <branch>       Checkout existing branch as worktree
p (s)witch <repo> [suffix]  Navigate to repo or worktree
p (d)one                    Remove current worktree and delete branch
p (g)oto                    Fuzzy-find and navigate to repo/worktree
p (u)se                     Fuzzy-find branch across all repos and switch
p (h)elp                    Show this help message

Configuration:
  WT_REPO_PARENTS              Parent directories to search for repos
  WT_REMOTE_PROJECTS           Projects to include remote branches in p use
  WT_DEFAULT_REMOTE            Remote name (default: "origin")
  WT_BRANCH_PREFIX_TEMPLATE    Branch naming template (default: '$(_wt_get_username)/')
EOF
}

p() {
  local cmd="${1:-}"

  if [[ -z "$cmd" ]]; then
    echo "Usage: p <(n)ew|(c)heckout|(s)witch|(d)one|(g)oto|(u)se|(h)elp> [args...]" >&2
    return 1
  fi

  shift

  case "$cmd" in
    new|n)
      wt-new "$@"
      ;;
    checkout|c)
      wt-checkout "$@"
      ;;
    switch|s)
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
    help|h)
      p-help "$@"
      ;;
    *)
      echo "Error: Unknown command '$cmd'" >&2
      echo "Available: (n)ew, (c)heckout, (s)witch, (d)one, (g)oto, (u)se, (h)elp" >&2
      return 1
      ;;
  esac
}
