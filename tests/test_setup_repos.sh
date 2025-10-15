#!/usr/bin/env bash
# Integration tests for setup_repos.sh
# Tests all supported repo import modes and branch resolution strategies

set -uo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Get script directory and repo root
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/.." && pwd)"
SETUP_SCRIPT="$REPO_ROOT/scripts/setup_repos.sh"

# Test workspace (cleaned up after tests)
TEST_ROOT=""

# Cleanup function
cleanup() {
  if [[ -n "$TEST_ROOT" && -d "$TEST_ROOT" ]]; then
    rm -rf "$TEST_ROOT"
  fi
}

trap cleanup EXIT

# Test result functions
pass() {
  echo -e "${GREEN}✓${NC} $1"
  ((TESTS_PASSED++))
}

fail() {
  echo -e "${RED}✗${NC} $1"
  echo -e "${RED}  $2${NC}"
  ((TESTS_FAILED++))
}

test_start() {
  ((TESTS_RUN++))
  echo -e "\n${YELLOW}▶${NC} Test $TESTS_RUN: $1"
}

# Create a fake remote git repository with branches
create_fake_remote() {
  local repo_path="$1"
  local default_branch="${2:-develop}"

  mkdir -p "$repo_path"
  cd "$repo_path"
  git init -q
  git config user.email "test@example.com"
  git config user.name "Test User"

  # Create initial commit on default branch
  echo "Initial commit" > README.md
  git add README.md
  git commit -q -m "Initial commit"

  # Rename to desired default branch if not already
  local current_branch
  current_branch=$(git branch --show-current)
  if [[ "$current_branch" != "$default_branch" ]]; then
    git branch -m "$current_branch" "$default_branch"
  fi

  # Create additional branches
  git checkout -q -b feature-a
  echo "Feature A" > feature-a.txt
  git add feature-a.txt
  git commit -q -m "Add feature A"

  git checkout -q "$default_branch"
  git checkout -q -b feature-b
  echo "Feature B" > feature-b.txt
  git add feature-b.txt
  git commit -q -m "Add feature B"

  git checkout -q "$default_branch"
}

# Verify worktree was created correctly
verify_worktree() {
  local workspace="$1"
  local repo_name="$2"
  local branch_name="$3"

  local safe_branch="${branch_name//\//-}"
  local worktree_path="$workspace/worktrees/$repo_name-$safe_branch"
  local bare_repo="$workspace/.repos/$repo_name.git"

  # Check worktree directory exists
  if [[ ! -d "$worktree_path" ]]; then
    fail "Worktree directory not found" "Expected: $worktree_path"
    return 1
  fi

  # Check it's a valid git worktree
  if ! git -C "$worktree_path" rev-parse --git-dir >/dev/null 2>&1; then
    fail "Not a valid git worktree" "Path: $worktree_path"
    return 1
  fi

  # Check correct branch is checked out
  local current_branch
  current_branch=$(git -C "$worktree_path" branch --show-current)
  if [[ "$current_branch" != "$branch_name" ]]; then
    fail "Wrong branch checked out" "Expected: $branch_name, Got: $current_branch"
    return 1
  fi

  # Check worktree is tracked by bare repo
  if ! git -C "$bare_repo" worktree list | grep -q "$worktree_path"; then
    fail "Worktree not registered in bare repo" "Bare repo: $bare_repo"
    return 1
  fi

  pass "Worktree created correctly: $repo_name-$safe_branch on branch $branch_name"
  return 0
}

# Verify bare repo was created correctly
verify_bare_repo() {
  local workspace="$1"
  local repo_name="$2"

  local bare_repo="$workspace/.repos/$repo_name.git"

  # Check bare repo exists
  if [[ ! -d "$bare_repo" ]]; then
    fail "Bare repo not found" "Expected: $bare_repo"
    return 1
  fi

  # Check it's a bare repo
  if [[ "$(git -C "$bare_repo" config --get core.bare)" != "true" ]]; then
    fail "Not a bare repository" "Path: $bare_repo"
    return 1
  fi

  # Check remote origin exists
  if ! git -C "$bare_repo" remote | grep -q "^origin$"; then
    fail "Origin remote not configured" "Bare repo: $bare_repo"
    return 1
  fi

  pass "Bare repo created correctly: $repo_name.git"
  return 0
}

# Test 1: Remote URL with default branch (develop)
test_remote_url_default_branch() {
  test_start "Remote URL with default branch (develop)"

  local test_dir="$TEST_ROOT/test1"
  mkdir -p "$test_dir/remote"

  # Create fake remote repo
  create_fake_remote "$test_dir/remote/test-repo" "develop"

  # Run setup script
  cd "$test_dir"
  local output
  output=$("$SETUP_SCRIPT" --repos "$test_dir/remote/test-repo" --default-branch develop 2>&1)
  if echo "$output" | grep -q "✅"; then
    verify_bare_repo "$test_dir" "test-repo"
    verify_worktree "$test_dir" "test-repo" "develop"
  else
    fail "Setup script failed" "$output"
  fi
}

# Test 2: Remote URL with main branch
test_remote_url_main_branch() {
  test_start "Remote URL with main branch"

  local test_dir="$TEST_ROOT/test2"
  mkdir -p "$test_dir/remote"

  # Create fake remote repo with main as default
  create_fake_remote "$test_dir/remote/test-repo-main" "main"

  # Run setup script (should auto-detect main)
  cd "$test_dir"
  local output
  output=$("$SETUP_SCRIPT" --repos "$test_dir/remote/test-repo-main" 2>&1)
  if echo "$output" | grep -q "✅"; then
    verify_bare_repo "$test_dir" "test-repo-main"
    verify_worktree "$test_dir" "test-repo-main" "main"
  else
    fail "Setup script failed" "$output"
  fi
}

# Test 3: Local path mode
test_local_path() {
  test_start "Local path mode"

  local test_dir="$TEST_ROOT/test3"
  mkdir -p "$test_dir/source"

  # Create source repo
  create_fake_remote "$test_dir/source/local-repo" "develop"

  # Run setup script with local path
  cd "$test_dir"
  local output
  output=$("$SETUP_SCRIPT" --repos "$test_dir/source/local-repo" --default-branch develop 2>&1)
  if echo "$output" | grep -q "✅"; then
    verify_bare_repo "$test_dir" "local-repo"
    verify_worktree "$test_dir" "local-repo" "develop"
  else
    fail "Setup script failed" "$output"
  fi
}

# Test 4: Per-repo branch override
test_per_repo_branch_override() {
  test_start "Per-repo branch override"

  local test_dir="$TEST_ROOT/test4"
  mkdir -p "$test_dir/remote"

  # Create fake remote repo
  create_fake_remote "$test_dir/remote/override-repo" "develop"

  # Run setup script with branch override (use feature-a instead of develop)
  cd "$test_dir"
  local output
  output=$("$SETUP_SCRIPT" --repos "$test_dir/remote/override-repo:feature-a" --default-branch develop 2>&1)
  if echo "$output" | grep -q "✅"; then
    verify_bare_repo "$test_dir" "override-repo"
    verify_worktree "$test_dir" "override-repo" "feature-a"
  else
    fail "Setup script failed" "$output"
  fi
}

# Test 5: Multiple repos
test_multiple_repos() {
  test_start "Multiple repos"

  local test_dir="$TEST_ROOT/test5"
  mkdir -p "$test_dir/remote"

  # Create two fake remote repos
  create_fake_remote "$test_dir/remote/repo-one" "develop"
  create_fake_remote "$test_dir/remote/repo-two" "main"

  # Run setup script with multiple repos
  cd "$test_dir"
  local output
  output=$("$SETUP_SCRIPT" --repos "$test_dir/remote/repo-one,$test_dir/remote/repo-two" 2>&1)
  if echo "$output" | grep -q "✅"; then
    verify_bare_repo "$test_dir" "repo-one"
    verify_worktree "$test_dir" "repo-one" "develop"
    verify_bare_repo "$test_dir" "repo-two"
    verify_worktree "$test_dir" "repo-two" "main"
  else
    fail "Setup script failed" "$output"
  fi
}

# Test 6: No initial worktrees flag
test_no_initial_worktrees() {
  test_start "No initial worktrees flag"

  local test_dir="$TEST_ROOT/test6"
  mkdir -p "$test_dir/remote"

  # Create fake remote repo
  create_fake_remote "$test_dir/remote/no-wt-repo" "develop"

  # Run setup script with --no-initial-worktrees
  cd "$test_dir"
  local output
  output=$("$SETUP_SCRIPT" --repos "$test_dir/remote/no-wt-repo" --no-initial-worktrees 2>&1)
  if echo "$output" | grep -q "Skipping initial worktree"; then
    verify_bare_repo "$test_dir" "no-wt-repo"

    # Verify NO worktree was created
    if [[ ! -d "$test_dir/worktrees/no-wt-repo-develop" ]]; then
      pass "No worktree created (as expected)"
    else
      fail "Worktree was created" "Should not exist with --no-initial-worktrees"
    fi
  else
    fail "Setup script failed" "$output"
  fi
}

# Test 7: Branch with slashes (e.g., release/2.0)
test_branch_with_slashes() {
  test_start "Branch with slashes (release/2.0)"

  local test_dir="$TEST_ROOT/test7"
  mkdir -p "$test_dir/remote"

  # Create fake remote repo with release branch
  cd "$test_dir/remote"
  create_fake_remote "$test_dir/remote/slash-repo" "develop"
  cd "$test_dir/remote/slash-repo"
  git checkout -q -b release/2.0
  echo "Release 2.0" > release.txt
  git add release.txt
  git commit -q -m "Release 2.0"
  git checkout -q develop

  # Run setup script with slash branch
  cd "$test_dir"
  local output
  output=$("$SETUP_SCRIPT" --repos "$test_dir/remote/slash-repo:release/2.0" 2>&1)
  if echo "$output" | grep -q "✅"; then
    verify_bare_repo "$test_dir" "slash-repo"
    # Should create worktree with sanitized name (release-2.0)
    verify_worktree "$test_dir" "slash-repo" "release/2.0"
  else
    fail "Setup script failed" "$output"
  fi
}

# Test 8: Existing worktree (idempotency)
test_existing_worktree() {
  test_start "Existing worktree (idempotency)"

  local test_dir="$TEST_ROOT/test8"
  mkdir -p "$test_dir/remote"

  # Create fake remote repo
  create_fake_remote "$test_dir/remote/existing-repo" "develop"

  # Run setup script twice
  cd "$test_dir"
  "$SETUP_SCRIPT" --repos "$test_dir/remote/existing-repo" --default-branch develop >/dev/null 2>&1

  local output
  output=$("$SETUP_SCRIPT" --repos "$test_dir/remote/existing-repo" --default-branch develop 2>&1)
  if echo "$output" | grep -q "Worktree exists"; then
    pass "Script handles existing worktree correctly"
  else
    fail "Script did not detect existing worktree" "$output"
  fi
}

# Test 9: Remote with non-standard default branch
test_remote_head_detection() {
  test_start "Remote HEAD detection"

  local test_dir="$TEST_ROOT/test9"
  mkdir -p "$test_dir/remote"

  # Create fake remote repo with custom default
  create_fake_remote "$test_dir/remote/head-repo" "develop"

  # Make it a bare repo to simulate real remote
  cd "$test_dir/remote"
  git clone --bare head-repo head-repo-bare.git
  cd head-repo-bare.git
  git symbolic-ref HEAD refs/heads/develop

  # Run setup script (should detect develop from HEAD)
  cd "$test_dir"
  local output
  output=$("$SETUP_SCRIPT" --repos "$test_dir/remote/head-repo-bare.git" 2>&1)
  if echo "$output" | grep -q "✅"; then
    verify_bare_repo "$test_dir" "head-repo-bare"
    verify_worktree "$test_dir" "head-repo-bare" "develop"
  else
    fail "Setup script failed" "$output"
  fi
}

# Test 10: Fallback when requested branch doesn't exist
test_fallback_nonexistent_branch() {
  test_start "Fallback when requested branch doesn't exist"

  local test_dir="$TEST_ROOT/test10"
  mkdir -p "$test_dir/remote"

  # Create fake remote repo with develop
  create_fake_remote "$test_dir/remote/fallback-repo" "develop"

  # Run setup script requesting nonexistent branch - should fall back to develop
  cd "$test_dir"
  local output
  output=$("$SETUP_SCRIPT" --repos "$test_dir/remote/fallback-repo:nonexistent" --default-branch develop 2>&1)

  # Should succeed by falling back to develop
  if echo "$output" | grep -q "✅" && echo "$output" | grep -q "Base branch: develop"; then
    verify_bare_repo "$test_dir" "fallback-repo"
    verify_worktree "$test_dir" "fallback-repo" "develop"
    pass "Script correctly falls back from nonexistent branch to develop"
  else
    fail "Script should fall back gracefully" "$output"
  fi
}

# Main test runner
main() {
  echo "======================================"
  echo "Integration Tests for setup_repos.sh"
  echo "======================================"

  # Create test root directory
  TEST_ROOT=$(mktemp -d)
  echo "Test workspace: $TEST_ROOT"

  # Run all tests
  test_remote_url_default_branch
  test_remote_url_main_branch
  test_local_path
  test_per_repo_branch_override
  test_multiple_repos
  test_no_initial_worktrees
  test_branch_with_slashes
  test_existing_worktree
  test_remote_head_detection
  test_fallback_nonexistent_branch

  # Summary
  echo ""
  echo "======================================"
  echo "Test Results"
  echo "======================================"
  echo "Tests run:    $TESTS_RUN"
  echo -e "Tests passed: ${GREEN}$TESTS_PASSED${NC}"
  if [[ $TESTS_FAILED -gt 0 ]]; then
    echo -e "Tests failed: ${RED}$TESTS_FAILED${NC}"
    exit 1
  else
    echo -e "Tests failed: ${GREEN}0${NC}"
    echo ""
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
  fi
}

# Check if setup script exists
if [[ ! -f "$SETUP_SCRIPT" ]]; then
  echo "ERROR: setup_repos.sh not found at $SETUP_SCRIPT"
  exit 1
fi

main
