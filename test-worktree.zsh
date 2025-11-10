#!/usr/bin/env zsh

# Test script for worktree.zsh branch listing functions

# Source the worktree module
source "${0:A:h}/worktree.zsh"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Helper functions
print_test() {
  echo "\n${YELLOW}TEST:${NC} $1"
  ((TESTS_RUN++))
}

print_pass() {
  echo "  ${GREEN}✓ PASS${NC}"
  ((TESTS_PASSED++))
}

print_fail() {
  echo "  ${RED}✗ FAIL${NC}: $1"
  ((TESTS_FAILED++))
}

print_info() {
  echo "  $1"
}

# ============================================================================
# Test: _wt_list_local_branches
# ============================================================================

print_test "_wt_list_local_branches returns only local branches"

local_branches=($(_wt_list_local_branches))

if [[ ${#local_branches} -eq 0 ]]; then
  print_fail "No local branches returned (are you in a git repo?)"
else
  print_info "Found ${#local_branches} local branch(es)"

  # Check that none have "remotes/" prefix
  local has_remote_prefix=false
  for branch in "${local_branches[@]}"; do
    if [[ "$branch" == remotes/* ]]; then
      has_remote_prefix=true
      print_fail "Branch '$branch' has remotes/ prefix"
      break
    fi
  done

  if [[ "$has_remote_prefix" == false ]]; then
    print_pass
    print_info "Sample: ${local_branches[1]}"
  fi
fi

# ============================================================================
# Test: _wt_list_remote_branches
# ============================================================================

print_test "_wt_list_remote_branches excludes locally-tracked branches"

remote_branches=($(_wt_list_remote_branches))
local_branches=($(_wt_list_local_branches))

if [[ ${#remote_branches} -eq 0 ]]; then
  print_info "No remote-only branches found (all remotes are tracked locally)"
  print_pass
else
  print_info "Found ${#remote_branches} remote-only branch(es)"

  # Check that no remote branch exists in local branches
  local has_duplicate=false
  for remote in "${remote_branches[@]}"; do
    # Check if this remote branch exists in local branches
    if (( ${local_branches[(Ie)$remote]} )); then
      has_duplicate=true
      print_fail "Remote branch '$remote' also exists in local branches"
      break
    fi

    # Check that it doesn't have remotes/ prefix
    if [[ "$remote" == remotes/* ]]; then
      has_duplicate=true
      print_fail "Remote branch '$remote' still has remotes/ prefix"
      break
    fi
  done

  if [[ "$has_duplicate" == false ]]; then
    print_pass
    print_info "Sample: ${remote_branches[1]}"
  fi
fi

# ============================================================================
# Test: _wt_list_all_branches
# ============================================================================

print_test "_wt_list_all_branches returns locals first, then remotes"

all_branches=($(_wt_list_all_branches))
local_count=${#local_branches}
remote_count=${#remote_branches}
expected_total=$((local_count + remote_count))

if [[ ${#all_branches} -ne $expected_total ]]; then
  print_fail "Expected $expected_total branches, got ${#all_branches}"
else
  print_info "Total: ${#all_branches} branches ($local_count local + $remote_count remote)"

  # Check that first N branches match local branches
  local order_correct=true
  for (( i=1; i<=local_count; i++ )); do
    if [[ "${all_branches[$i]}" != "${local_branches[$i]}" ]]; then
      order_correct=false
      print_fail "Branch at position $i doesn't match: expected '${local_branches[$i]}', got '${all_branches[$i]}'"
      break
    fi
  done

  if [[ "$order_correct" == true ]]; then
    # Check that remaining branches are remote branches
    for (( i=1; i<=remote_count; i++ )); do
      local pos=$((local_count + i))
      if [[ "${all_branches[$pos]}" != "${remote_branches[$i]}" ]]; then
        order_correct=false
        print_fail "Remote branch at position $pos doesn't match: expected '${remote_branches[$i]}', got '${all_branches[$pos]}'"
        break
      fi
    done
  fi

  if [[ "$order_correct" == true ]]; then
    print_pass
    if [[ $local_count -gt 0 ]]; then
      print_info "First local: ${all_branches[1]}"
    fi
    if [[ $remote_count -gt 0 ]]; then
      print_info "First remote: ${all_branches[$((local_count + 1))]}"
    fi
  fi
fi

# ============================================================================
# Test: No duplicates in _wt_list_all_branches
# ============================================================================

print_test "_wt_list_all_branches contains no duplicates"

# Use associative array to track seen branches
typeset -A seen_branches
local has_duplicates=false
local duplicate_branch=""

for branch in "${all_branches[@]}"; do
  if [[ -n "${seen_branches[$branch]}" ]]; then
    has_duplicates=true
    duplicate_branch="$branch"
    break
  fi
  seen_branches[$branch]=1
done

if [[ "$has_duplicates" == true ]]; then
  print_fail "Duplicate branch found: '$duplicate_branch'"
else
  print_pass
  print_info "All ${#all_branches} branches are unique"
fi

# ============================================================================
# Summary
# ============================================================================

local separator=$(printf '=%.0s' {1..60})
echo "\n$separator"
echo "TEST SUMMARY"
echo "$separator"
echo "Total tests run:    $TESTS_RUN"
echo "Tests passed:       ${GREEN}$TESTS_PASSED${NC}"
if [[ $TESTS_FAILED -gt 0 ]]; then
  echo "Tests failed:       ${RED}$TESTS_FAILED${NC}"
else
  echo "Tests failed:       $TESTS_FAILED"
fi
echo "$separator"

if [[ $TESTS_FAILED -eq 0 ]]; then
  echo "${GREEN}All tests passed!${NC}"
  exit 0
else
  echo "${RED}Some tests failed!${NC}"
  exit 1
fi
