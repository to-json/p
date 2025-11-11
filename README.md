# Git Worktree Management

Shell functions for managing git worktrees across multiple repositories.

Basically, I don't think "I am going to go work on project X" should involve
the idea of directories, or worktrees, or whatever, you should be able to refer
directly to branches and projects and let your tools do the rest.

AI disclosure: this shit is like 98% vibes. works well tho. reads ok too.

## Installation

```bash
# Add to ~/.zshrc
source "$LOCATION/worktree.zsh"
source "$LOCATION/p.zsh"

# Add to fpath for completions
fpath=($LOCATION/ $fpath)
```

## Usage

### Via `p` interface (recommended)

```bash
p n my-feature          # Create new worktree with branch username/my-feature
p c feature-branch      # Checkout existing branch as worktree
p s myrepo              # Switch to repo main worktree
p s myrepo feature      # Switch to myrepo.feature worktree
p u                     # Fuzzy find across all branches and switch
p g                     # Fuzzy find across all repos/worktrees
p d                     # Remove current worktree and delete branch
p h                     # Show help
```

### Via `wt-*` functions

```bash
wt-new my-feature
wt-checkout feature-branch
wt-cd myrepo [suffix]
wt-use
wt-goto
wt-done
wt-help
```

## Configuration

Edit these arrays in `worktree.zsh`:

```zsh
WT_REPO_PARENTS=(
  "$HOME/code"
  "$HOME/scripts"
)

WT_REMOTE_PROJECTS=(
  webapp
  backend
)

WT_DEFAULT_REMOTE="origin"

WT_BRANCH_PREFIX_TEMPLATE='$(_wt_get_username)/'
```

## Worktree Layout

```
~/code/
  myrepo/              # Main worktree (branch: main)
  myrepo.feature-1/    # Linked worktree (branch: jae/feature-1)
  myrepo.bugfix/       # Linked worktree (branch: jae/bugfix)
```

## Dependencies

- zsh
- git
- gum (optional, sorta, just install it anyway)

## Testing

```bash
./test-worktree.zsh
```
