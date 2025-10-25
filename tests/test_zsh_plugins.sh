#!/usr/bin/env bash
# Integration tests for zsh plugins
# Tests config loading, shorthand resolution, and helper functions

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

# Test workspace
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
  if [[ -n "${2:-}" ]]; then
    echo -e "${RED}  $2${NC}"
  fi
  ((TESTS_FAILED++))
}

test_start() {
  ((TESTS_RUN++))
  echo -e "\n${YELLOW}▶${NC} Test $TESTS_RUN: $1"
}

# =============================================================================
# Helper Functions for Testing
# =============================================================================

# Create a test config file
create_test_config() {
  local config_path="$1"
  mkdir -p "$(dirname "$config_path")"

  cat > "$config_path" << 'EOF'
GIT_USERNAME="${USER}"
BRANCH_PREFIX="${USER}"
BASE_DEV_PATH="/tmp/test_workspace"
BARE_REPOS_PATH="$BASE_DEV_PATH/.repos"
WORKTREES_PATH="$BASE_DEV_PATH/worktrees"
WORKTREE_TEMPLATES_PATH="$BASE_DEV_PATH/worktree_templates"

[[ -z ${(t)REPO_MAPPINGS} ]] && declare -gA REPO_MAPPINGS
REPO_MAPPINGS[web]="TestApp-WebApp"
REPO_MAPPINGS[android]="TestApp-Android"
REPO_MAPPINGS[ios]="TestApp-iOS"

REPO_CONFIGS[web]="npm run build|npm test|npm run lint"
REPO_CONFIGS[android]="./gradlew assembleDebug|./gradlew test|./gradlew lint"
REPO_CONFIGS[ios]="bundle exec fastlane build|bundle exec fastlane test|swiftlint"

REPO_MODULES[web]="packages/ui packages/api"
REPO_MODULES[android]="feature-auth feature-profile"

REPO_IDE_CONFIGS[web]="vscode||"
REPO_IDE_CONFIGS[android]="android-studio||"
REPO_IDE_CONFIGS[ios]="xcode-workspace|TestApp-iOS.xcworkspace|"
EOF
}

# Source ci-helper functions in isolation
source_ci_helper() {
  local config_path="$1"

  zsh -c "
    HOME='$(dirname "$config_path")'
    source '$SCRIPT_DIR/ci-helper.zsh'
    _load_ci_helper_impl

    # Export test functions
    typeset -f resolve_to_shorthand
    typeset -f get_repo_config
    typeset -f get_repo_modules
    typeset -f get_repo_ide_config
  "
}

# =============================================================================
# Tests
# =============================================================================

# Test 1: Config loading with smart defaults
test_config_loading() {
  test_start "Config loading with smart defaults"

  local test_dir="$TEST_ROOT/test1"
  mkdir -p "$test_dir/.config/worktree-tools"

  # Create minimal config
  cat > "$test_dir/.config/worktree-tools/config.zsh" << 'EOF'
GIT_USERNAME="${USER}"
BRANCH_PREFIX="${USER}"
BASE_DEV_PATH="$HOME/dev"
EOF

  # Test that config loads and USER is substituted
  local result=$(HOME="$test_dir" USER="testuser" zsh -c '
    source "'$SCRIPT_DIR'/git-worktree-helper.zsh"
    _load_git_worktree_impl
    echo "USER=$GIT_USERNAME"
    echo "PREFIX=$BRANCH_PREFIX"
    echo "BASE=$BASE_DEV_PATH"
  ')

  if echo "$result" | grep -q "USER=testuser" && \
     echo "$result" | grep -q "PREFIX=testuser" && \
     echo "$result" | grep -q "BASE=$test_dir/dev"; then
    pass "Config loads with USER variable substitution"
  else
    fail "Config loading failed" "$result"
  fi
}

# Test 2: Shorthand resolution (shorthand → shorthand)
test_shorthand_to_shorthand() {
  test_start "Shorthand resolution: shorthand input"

  local test_dir="$TEST_ROOT/test2"
  create_test_config "$test_dir/.config/worktree-tools/config.zsh"

  local result=$(HOME="$test_dir" zsh -c '
    source "'$SCRIPT_DIR'/ci-helper.zsh"
    _load_ci_helper_impl
    resolve_to_shorthand "web"
  ')

  if [[ "$result" == "web" ]]; then
    pass "Shorthand 'web' resolves to 'web'"
  else
    fail "Expected 'web', got '$result'"
  fi
}

# Test 3: Shorthand resolution (full name → shorthand)
test_fullname_to_shorthand() {
  test_start "Shorthand resolution: full name input"

  local test_dir="$TEST_ROOT/test3"
  create_test_config "$test_dir/.config/worktree-tools/config.zsh"

  local result=$(HOME="$test_dir" zsh -c '
    source "'$SCRIPT_DIR'/ci-helper.zsh"
    _load_ci_helper_impl
    resolve_to_shorthand "TestApp-Android"
  ')

  if [[ "$result" == "android" ]]; then
    pass "Full name 'TestApp-Android' resolves to 'android'"
  else
    fail "Expected 'android', got '$result'" "$result"
  fi
}

# Test 4: Get repo config using shorthand
test_get_config_shorthand() {
  test_start "Get repo config using shorthand"

  local test_dir="$TEST_ROOT/test4"
  create_test_config "$test_dir/.config/worktree-tools/config.zsh"

  local result=$(HOME="$test_dir" zsh -c '
    source "'$SCRIPT_DIR'/ci-helper.zsh"
    _load_ci_helper_impl
    get_repo_config "web"
  ')

  if echo "$result" | grep -q "npm run build"; then
    pass "Config retrieved using shorthand 'web'"
  else
    fail "Config retrieval failed" "$result"
  fi
}

# Test 5: Get repo config using full name (backward compat)
test_get_config_fullname() {
  test_start "Get repo config using full name (backward compat)"

  local test_dir="$TEST_ROOT/test5"
  create_test_config "$test_dir/.config/worktree-tools/config.zsh"

  local result=$(HOME="$test_dir" zsh -c '
    source "'$SCRIPT_DIR'/ci-helper.zsh"
    _load_ci_helper_impl
    get_repo_config "TestApp-Android"
  ')

  if echo "$result" | grep -q "./gradlew assembleDebug"; then
    pass "Config retrieved using full name (backward compatible)"
  else
    fail "Backward compat config retrieval failed" "$result"
  fi
}

# Test 6: Get repo modules
test_get_modules() {
  test_start "Get repo modules"

  local test_dir="$TEST_ROOT/test6"
  create_test_config "$test_dir/.config/worktree-tools/config.zsh"

  local result=$(HOME="$test_dir" zsh -c '
    source "'$SCRIPT_DIR'/ci-helper.zsh"
    _load_ci_helper_impl
    get_repo_modules "android"
  ')

  if echo "$result" | grep -q "feature-auth" && \
     echo "$result" | grep -q "feature-profile"; then
    pass "Modules retrieved for 'android'"
  else
    fail "Module retrieval failed" "$result"
  fi
}

# Test 7: Get IDE config
test_get_ide_config() {
  test_start "Get IDE config"

  local test_dir="$TEST_ROOT/test7"
  create_test_config "$test_dir/.config/worktree-tools/config.zsh"

  local result=$(HOME="$test_dir" zsh -c '
    source "'$SCRIPT_DIR'/ci-helper.zsh"
    _load_ci_helper_impl
    get_repo_ide_config "ios"
  ')

  if echo "$result" | grep -q "xcode-workspace"; then
    pass "IDE config retrieved for 'ios'"
  else
    fail "IDE config retrieval failed" "$result"
  fi
}

# Test 8: Empty BRANCH_PREFIX handling
test_empty_branch_prefix() {
  test_start "Empty BRANCH_PREFIX handling"

  local result=$(zsh -c '
    BRANCH_PREFIX=""
    branch_name="my-feature"

    if [[ -n $BRANCH_PREFIX ]]; then
        prefixed_branch="$BRANCH_PREFIX/$branch_name"
    else
        prefixed_branch="$branch_name"
    fi

    echo "$prefixed_branch"
  ')

  if [[ "$result" == "my-feature" ]]; then
    pass "Empty prefix produces branch without prefix"
  else
    fail "Expected 'my-feature', got '$result'"
  fi
}

# Test 9: Non-empty BRANCH_PREFIX handling
test_nonempty_branch_prefix() {
  test_start "Non-empty BRANCH_PREFIX handling"

  local result=$(zsh -c '
    BRANCH_PREFIX="john"
    branch_name="my-feature"

    if [[ -n $BRANCH_PREFIX ]]; then
        prefixed_branch="$BRANCH_PREFIX/$branch_name"
    else
        prefixed_branch="$branch_name"
    fi

    echo "$prefixed_branch"
  ')

  if [[ "$result" == "john/my-feature" ]]; then
    pass "Non-empty prefix produces 'john/my-feature'"
  else
    fail "Expected 'john/my-feature', got '$result'"
  fi
}

# Test 10: Plugin loads without errors
test_plugin_loading() {
  test_start "Plugins load without errors"

  local errors=$(zsh -c "
    source '$SCRIPT_DIR/git-worktree-helper.zsh' 2>&1 || echo 'ERROR'
    source '$SCRIPT_DIR/ci-helper.zsh' 2>&1 || echo 'ERROR'
  " | grep ERROR)

  if [[ -z "$errors" ]]; then
    pass "Both plugins load without errors"
  else
    fail "Plugin loading failed" "$errors"
  fi
}

# Test 11: Unknown repo returns empty config
test_unknown_repo() {
  test_start "Unknown repo returns empty config"

  local test_dir="$TEST_ROOT/test11"
  create_test_config "$test_dir/.config/worktree-tools/config.zsh"

  local result=$(HOME="$test_dir" zsh -c '
    source "'$SCRIPT_DIR'/ci-helper.zsh"
    _load_ci_helper_impl
    get_repo_config "nonexistent"
  ')

  if [[ -z "$result" ]]; then
    pass "Unknown repo returns empty config"
  else
    fail "Expected empty result, got '$result'"
  fi
}

# Test 12: All three platform examples work
test_platform_examples() {
  test_start "All platform examples (web/android/ios)"

  local test_dir="$TEST_ROOT/test12"
  create_test_config "$test_dir/.config/worktree-tools/config.zsh"

  local web=$(HOME="$test_dir" zsh -c '
    source "'$SCRIPT_DIR'/ci-helper.zsh"
    _load_ci_helper_impl
    get_repo_config "web"
  ')

  local android=$(HOME="$test_dir" zsh -c '
    source "'$SCRIPT_DIR'/ci-helper.zsh"
    _load_ci_helper_impl
    get_repo_config "android"
  ')

  local ios=$(HOME="$test_dir" zsh -c '
    source "'$SCRIPT_DIR'/ci-helper.zsh"
    _load_ci_helper_impl
    get_repo_config "ios"
  ')

  if echo "$web" | grep -q "npm" && \
     echo "$android" | grep -q "gradlew" && \
     echo "$ios" | grep -q "fastlane"; then
    pass "All three platforms configured correctly"
  else
    fail "Platform configs incomplete" "web=$web, android=$android, ios=$ios"
  fi
}

# =============================================================================
# IDE Detection Tests
# =============================================================================

# Test 13: IDE detection for Android project
test_ide_detection_android() {
  test_start "IDE detection for Android/Gradle project"

  local test_dir="$TEST_ROOT/test13"
  mkdir -p "$test_dir/android_repo"
  touch "$test_dir/android_repo/gradlew"
  create_test_config "$test_dir/.config/worktree-tools/config.zsh"

  local result=$(HOME="$test_dir" zsh -c '
    source "'$SCRIPT_DIR'/ci-helper.zsh"
    _load_ci_helper_impl
    detect_ide_info "'$test_dir'/android_repo" "android"
  ')

  if echo "$result" | grep -q "android-studio"; then
    pass "Android Studio detected for gradlew project"
  else
    fail "Expected android-studio detection" "Got: $result"
  fi
}

# Test 14: IDE detection for Swift Package
test_ide_detection_swift_package() {
  test_start "IDE detection for Swift Package"

  local test_dir="$TEST_ROOT/test14"
  mkdir -p "$test_dir/swift_repo/.swiftpm/xcode"
  touch "$test_dir/swift_repo/Package.swift"
  mkdir -p "$test_dir/swift_repo/.swiftpm/xcode/package.xcworkspace"
  create_test_config "$test_dir/.config/worktree-tools/config.zsh"

  local result=$(HOME="$test_dir" zsh -c '
    source "'$SCRIPT_DIR'/ci-helper.zsh"
    _load_ci_helper_impl
    detect_ide_info "'$test_dir'/swift_repo" "unknown"
  ')

  if echo "$result" | grep -q "xcode-package"; then
    pass "Xcode detected for Swift Package"
  else
    fail "Expected xcode-package detection" "Got: $result"
  fi
}

# Test 15: IDE detection for Xcode workspace
test_ide_detection_xcode_workspace() {
  test_start "IDE detection for Xcode workspace"

  local test_dir="$TEST_ROOT/test15"
  mkdir -p "$test_dir/ios_repo/MyApp.xcworkspace"
  create_test_config "$test_dir/.config/worktree-tools/config.zsh"

  local result=$(HOME="$test_dir" zsh -c '
    source "'$SCRIPT_DIR'/ci-helper.zsh"
    _load_ci_helper_impl
    detect_ide_info "'$test_dir'/ios_repo" "unknown"
  ')

  if echo "$result" | grep -q "xcode-workspace"; then
    pass "Xcode workspace detected"
  else
    fail "Expected xcode-workspace detection" "Got: $result"
  fi
}

# Test 16: IDE detection with configured IDE type
test_ide_detection_configured() {
  test_start "IDE detection with explicit configuration"

  local test_dir="$TEST_ROOT/test16"
  mkdir -p "$test_dir/.config/worktree-tools"
  create_test_config "$test_dir/.config/worktree-tools/config.zsh"

  local result=$(HOME="$test_dir" zsh -c '
    source "'$SCRIPT_DIR'/ci-helper.zsh"
    _load_ci_helper_impl
    detect_ide_info "/fake/path" "ios"
  ')

  if echo "$result" | grep -q "xcode-workspace"; then
    pass "Configured IDE type used"
  else
    fail "Expected configured IDE type" "Got: $result"
  fi
}

# Test 17: IDE detection fallback to default
test_ide_detection_default() {
  test_start "IDE detection fallback to default editor"

  local test_dir="$TEST_ROOT/test17"
  mkdir -p "$test_dir/unknown_repo"
  create_test_config "$test_dir/.config/worktree-tools/config.zsh"

  local result=$(HOME="$test_dir" zsh -c '
    source "'$SCRIPT_DIR'/ci-helper.zsh"
    _load_ci_helper_impl
    detect_ide_info "'$test_dir'/unknown_repo" "unknown"
  ')

  if echo "$result" | grep -q "default"; then
    pass "Default editor fallback works"
  else
    fail "Expected default fallback" "Got: $result"
  fi
}

# =============================================================================
# Build Command Construction Tests
# =============================================================================

# Test 18: Build gradle command with single module
test_build_gradle_single_module() {
  test_start "Build gradle command with single module"

  local test_dir="$TEST_ROOT/test18"
  mkdir -p "$test_dir/.config/worktree-tools"
  cat > "$test_dir/.config/worktree-tools/config.zsh" << 'EOF'
[[ -z ${(t)REPO_MAPPINGS} ]] && declare -gA REPO_MAPPINGS
[[ -z ${(t)REPO_CONFIGS} ]] && declare -gA REPO_CONFIGS
[[ -z ${(t)REPO_MODULES} ]] && declare -gA REPO_MODULES
REPO_MAPPINGS[test]="TestRepo"
REPO_CONFIGS[test]="./gradlew build|./gradlew test|./gradlew lint"
REPO_MODULES[test]="core-module"
EOF

  local result=$(HOME="$test_dir" zsh -c '
    source "'$SCRIPT_DIR'/ci-helper.zsh"
    _load_ci_helper_impl
    build_gradle_command "test" "assembleDebug"
  ')

  local expected="./gradlew --quiet :core-module:assembleDebug"
  if [[ "$result" == "$expected" ]]; then
    pass "Single module gradle command built correctly"
  else
    fail "Expected: $expected" "Got: $result"
  fi
}

# Test 19: Build gradle command with multiple modules and tasks
test_build_gradle_multiple_modules() {
  test_start "Build gradle command with multiple modules and tasks"

  local test_dir="$TEST_ROOT/test19"
  mkdir -p "$test_dir/.config/worktree-tools"
  cat > "$test_dir/.config/worktree-tools/config.zsh" << 'EOF'
[[ -z ${(t)REPO_MAPPINGS} ]] && declare -gA REPO_MAPPINGS
[[ -z ${(t)REPO_CONFIGS} ]] && declare -gA REPO_CONFIGS
[[ -z ${(t)REPO_MODULES} ]] && declare -gA REPO_MODULES
REPO_MAPPINGS[test]="TestRepo"
REPO_CONFIGS[test]="./gradlew build|./gradlew test|./gradlew lint"
REPO_MODULES[test]="module-a module-b"
EOF

  local result=$(HOME="$test_dir" zsh -c '
    source "'$SCRIPT_DIR'/ci-helper.zsh"
    _load_ci_helper_impl
    build_gradle_command "test" "assembleDebug" "testDebugUnitTest"
  ')

  # Should have both tasks for both modules
  if echo "$result" | grep -q ":module-a:assembleDebug" && \
     echo "$result" | grep -q ":module-a:testDebugUnitTest" && \
     echo "$result" | grep -q ":module-b:assembleDebug" && \
     echo "$result" | grep -q ":module-b:testDebugUnitTest"; then
    pass "Multiple modules and tasks command built correctly"
  else
    fail "Command missing expected tasks" "Got: $result"
  fi
}

# Test 20: Build gradle command with no modules returns error
test_build_gradle_no_modules() {
  test_start "Build gradle command with no modules configured"

  local test_dir="$TEST_ROOT/test20"
  mkdir -p "$test_dir/.config/worktree-tools"
  cat > "$test_dir/.config/worktree-tools/config.zsh" << 'EOF'
[[ -z ${(t)REPO_MAPPINGS} ]] && declare -gA REPO_MAPPINGS
[[ -z ${(t)REPO_CONFIGS} ]] && declare -gA REPO_CONFIGS
[[ -z ${(t)REPO_MODULES} ]] && declare -gA REPO_MODULES
REPO_MAPPINGS[noop]="NoModules-Repo"
REPO_CONFIGS[noop]="./gradlew build|./gradlew test|./gradlew lint"
# Intentionally no REPO_MODULES[noop] entry
EOF

  local result=$(HOME="$test_dir" zsh -c '
    source "'$SCRIPT_DIR'/ci-helper.zsh"
    _load_ci_helper_impl
    build_gradle_command "noop" "assembleDebug" 2>&1
    echo "EXIT_CODE:$?"
  ')

  if echo "$result" | grep -q "EXIT_CODE:1"; then
    pass "Correctly returns error for repo with no modules"
  else
    fail "Expected error for missing modules" "Got: $result"
  fi
}

# =============================================================================
# Git Worktree Integration Tests
# =============================================================================

# Helper function to setup bare repo for worktree tests
# This mimics the structure created by setup_repos.sh
setup_bare_repo_for_worktree_tests() {
  local test_dir=$1
  local repo_name=$2

  # Create a source "remote" repo
  local source_repo="$test_dir/source/$repo_name"
  mkdir -p "$source_repo"
  cd "$source_repo"
  git init -q
  git config user.email "test@example.com"
  git config user.name "Test User"

  echo "Initial commit" > README.md
  git add README.md
  git commit -q -m "Initial commit"
  git branch -m main

  # Clone as bare repo with proper remote tracking
  local bare_repo="$test_dir/.repos/$repo_name.git"
  mkdir -p "$(dirname "$bare_repo")"
  git clone --bare "$source_repo" "$bare_repo" >/dev/null 2>&1

  # Configure remote tracking branches in the bare repo
  cd "$bare_repo"
  git config remote.origin.url "$source_repo"
  git config remote.origin.fetch "+refs/heads/*:refs/remotes/origin/*"
  git fetch origin >/dev/null 2>&1

  echo "$bare_repo"
}

# Test 21: Add worktree with new branch
test_worktree_add_new_branch() {
  test_start "Add worktree with new branch"

  local test_dir="$TEST_ROOT/test21"
  local bare_repo=$(setup_bare_repo_for_worktree_tests "$test_dir" "test-repo")

  # Create config for worktree tests
  mkdir -p "$test_dir/.config/worktree-tools"
  cat > "$test_dir/.config/worktree-tools/config.zsh" <<EOF
[[ -z \${(t)REPO_MAPPINGS} ]] && declare -gA REPO_MAPPINGS
REPO_MAPPINGS[test]="test-repo"
BRANCH_PREFIX="testuser"
BASE_DEV_PATH="$test_dir"
BARE_REPOS_PATH="$test_dir/.repos"
WORKTREES_PATH="$test_dir/worktrees"
WORKTREE_TEMPLATES_PATH="$test_dir/worktree_templates"
EOF

  # Run add_worktree
  local output=$(HOME="$test_dir" zsh -c '
    source "'$SCRIPT_DIR'/git-worktree-helper.zsh"
    _load_git_worktree_impl
    add_worktree "test" "feature-branch" 2>&1
  ')

  # Verify worktree was created
  if git -C "$bare_repo" worktree list | grep -q "testuser/feature-branch"; then
    pass "Worktree created with new branch"
  else
    fail "Worktree not found" "$output"
  fi
}

# Test 22: Switch to existing worktree
test_worktree_switch() {
  test_start "Switch to existing worktree (fuzzy match)"

  local test_dir="$TEST_ROOT/test22"
  local bare_repo=$(setup_bare_repo_for_worktree_tests "$test_dir" "test-repo")

  # Create config
  mkdir -p "$test_dir/.config/worktree-tools"
  cat > "$test_dir/.config/worktree-tools/config.zsh" <<EOF
[[ -z \${(t)REPO_MAPPINGS} ]] && declare -gA REPO_MAPPINGS
REPO_MAPPINGS[test]="test-repo"
BRANCH_PREFIX="testuser"
BASE_DEV_PATH="$test_dir"
BARE_REPOS_PATH="$test_dir/.repos"
WORKTREES_PATH="$test_dir/worktrees"
EOF

  # Add a worktree first
  HOME="$test_dir" zsh -c '
    source "'$SCRIPT_DIR'/git-worktree-helper.zsh"
    _load_git_worktree_impl
    add_worktree "test" "my-feature" >/dev/null 2>&1
  '

  # Test switching with partial match
  local output=$(HOME="$test_dir" zsh -c '
    source "'$SCRIPT_DIR'/git-worktree-helper.zsh"
    _load_git_worktree_impl
    switch_worktree "test" "feature" 2>&1
  ')

  if echo "$output" | grep -q "WORKTREE_CD_TARGET"; then
    pass "Worktree switch with fuzzy match works"
  else
    fail "Switch did not find matching worktree" "$output"
  fi
}

# Test 23: Remove worktree
test_worktree_remove() {
  test_start "Remove existing worktree"

  local test_dir="$TEST_ROOT/test23"
  local bare_repo=$(setup_bare_repo_for_worktree_tests "$test_dir" "test-repo")

  # Create config
  mkdir -p "$test_dir/.config/worktree-tools"
  cat > "$test_dir/.config/worktree-tools/config.zsh" <<EOF
[[ -z \${(t)REPO_MAPPINGS} ]] && declare -gA REPO_MAPPINGS
REPO_MAPPINGS[test]="test-repo"
BRANCH_PREFIX="testuser"
BASE_DEV_PATH="$test_dir"
BARE_REPOS_PATH="$test_dir/.repos"
WORKTREES_PATH="$test_dir/worktrees"
EOF

  # Add a worktree first
  HOME="$test_dir" zsh -c '
    source "'$SCRIPT_DIR'/git-worktree-helper.zsh"
    _load_git_worktree_impl
    add_worktree "test" "temp-branch" >/dev/null 2>&1
  '

  # Remove it
  HOME="$test_dir" zsh -c '
    source "'$SCRIPT_DIR'/git-worktree-helper.zsh"
    _load_git_worktree_impl
    remove_worktree "test" "test-repo-temp-branch" >/dev/null 2>&1
  '

  # Verify it's gone
  if ! git -C "$bare_repo" worktree list | grep -q "temp-branch"; then
    pass "Worktree removed successfully"
  else
    fail "Worktree still exists after removal"
  fi
}

# Test 24: Template copy on worktree creation
test_worktree_template_copy() {
  test_start "Template files copied to new worktree"

  local test_dir="$TEST_ROOT/test24"
  local bare_repo=$(setup_bare_repo_for_worktree_tests "$test_dir" "test-repo")

  # Create template files
  mkdir -p "$test_dir/worktree_templates/test-repo"
  echo "test content" > "$test_dir/worktree_templates/test-repo/.test_file"

  # Create config
  mkdir -p "$test_dir/.config/worktree-tools"
  cat > "$test_dir/.config/worktree-tools/config.zsh" <<EOF
[[ -z \${(t)REPO_MAPPINGS} ]] && declare -gA REPO_MAPPINGS
REPO_MAPPINGS[test]="test-repo"
BRANCH_PREFIX="testuser"
BASE_DEV_PATH="$test_dir"
BARE_REPOS_PATH="$test_dir/.repos"
WORKTREES_PATH="$test_dir/worktrees"
WORKTREE_TEMPLATES_PATH="$test_dir/worktree_templates"
EOF

  # Add worktree (should auto-copy templates)
  HOME="$test_dir" zsh -c '
    source "'$SCRIPT_DIR'/git-worktree-helper.zsh"
    _load_git_worktree_impl
    add_worktree "test" "with-template" >/dev/null 2>&1
  '

  # Check if template file exists in worktree
  local worktree_path="$test_dir/worktrees/test-repo-with-template"
  if [[ -f "$worktree_path/.test_file" ]]; then
    pass "Template file copied to new worktree"
  else
    fail "Template file not found in worktree" "Path: $worktree_path"
  fi
}

# Test 25: List worktrees
test_worktree_list() {
  test_start "List all worktrees for repository"

  local test_dir="$TEST_ROOT/test25"
  local bare_repo=$(setup_bare_repo_for_worktree_tests "$test_dir" "test-repo")

  # Create config
  mkdir -p "$test_dir/.config/worktree-tools"
  cat > "$test_dir/.config/worktree-tools/config.zsh" <<EOF
[[ -z \${(t)REPO_MAPPINGS} ]] && declare -gA REPO_MAPPINGS
REPO_MAPPINGS[test]="test-repo"
BRANCH_PREFIX="testuser"
BASE_DEV_PATH="$test_dir"
BARE_REPOS_PATH="$test_dir/.repos"
WORKTREES_PATH="$test_dir/worktrees"
EOF

  # Add multiple worktrees
  HOME="$test_dir" zsh -c '
    source "'$SCRIPT_DIR'/git-worktree-helper.zsh"
    _load_git_worktree_impl
    add_worktree "test" "branch-one" >/dev/null 2>&1
    add_worktree "test" "branch-two" >/dev/null 2>&1
  '

  # List worktrees
  local output=$(HOME="$test_dir" zsh -c '
    source "'$SCRIPT_DIR'/git-worktree-helper.zsh"
    _load_git_worktree_impl
    list_worktrees "test" 2>&1
  ')

  if echo "$output" | grep -q "branch-one" && echo "$output" | grep -q "branch-two"; then
    pass "List shows all worktrees"
  else
    fail "List output incomplete" "$output"
  fi
}

# Test 26: Branch prefix validation
test_branch_prefix_validation() {
  test_start "Branch name with slash rejected when prefix configured"

  local test_dir="$TEST_ROOT/test26"
  local bare_repo=$(setup_bare_repo_for_worktree_tests "$test_dir" "test-repo")

  # Create config with branch prefix
  mkdir -p "$test_dir/.config/worktree-tools"
  cat > "$test_dir/.config/worktree-tools/config.zsh" <<EOF
[[ -z \${(t)REPO_MAPPINGS} ]] && declare -gA REPO_MAPPINGS
REPO_MAPPINGS[test]="test-repo"
BRANCH_PREFIX="testuser"
BASE_DEV_PATH="$test_dir"
BARE_REPOS_PATH="$test_dir/.repos"
WORKTREES_PATH="$test_dir/worktrees"
EOF

  # Try to add worktree with slash in name (should fail)
  local output=$(HOME="$test_dir" zsh -c '
    source "'$SCRIPT_DIR'/git-worktree-helper.zsh"
    _load_git_worktree_impl
    add_worktree "test" "feature/branch" 2>&1
    echo "EXIT_CODE:$?"
  ')

  if echo "$output" | grep -q "EXIT_CODE:1"; then
    pass "Branch name with slash correctly rejected"
  else
    fail "Should reject branch name with slash" "$output"
  fi
}

# Test 27: No REPO_MAPPINGS defined
test_no_repo_mappings() {
  test_start "Handle config with no REPO_MAPPINGS defined"

  local test_dir="$TEST_ROOT/test27"
  mkdir -p "$test_dir/.config/worktree-tools"

  # Create config without REPO_MAPPINGS
  cat > "$test_dir/.config/worktree-tools/config.zsh" << 'EOF'
# Config with no REPO_MAPPINGS - using direct keys only
[[ -z ${(t)REPO_CONFIGS} ]] && declare -gA REPO_CONFIGS
REPO_CONFIGS[DirectRepo]="npm build|npm test|npm lint"
EOF

  # Test that resolve_to_shorthand handles missing REPO_MAPPINGS gracefully
  local result=$(HOME="$test_dir" zsh -c '
    source "'$SCRIPT_DIR'/ci-helper.zsh"
    _load_ci_helper_impl
    # Should return input as-is when REPO_MAPPINGS is empty
    resolve_to_shorthand "DirectRepo"
  ')

  if [[ "$result" == "DirectRepo" ]]; then
    pass "Handles missing REPO_MAPPINGS gracefully"
  else
    fail "Expected 'DirectRepo', got '$result'"
  fi
}

# Test 28: No IDE config for a repo - falls back to heuristics
test_no_ide_config_fallback() {
  test_start "No IDE config - fallback to heuristics"

  local test_dir="$TEST_ROOT/test28"
  mkdir -p "$test_dir/.config/worktree-tools"

  # Create config without REPO_IDE_CONFIGS for this repo
  cat > "$test_dir/.config/worktree-tools/config.zsh" << 'EOF'
[[ -z ${(t)REPO_MAPPINGS} ]] && declare -gA REPO_MAPPINGS
[[ -z ${(t)REPO_CONFIGS} ]] && declare -gA REPO_CONFIGS
[[ -z ${(t)REPO_IDE_CONFIGS} ]] && declare -gA REPO_IDE_CONFIGS
REPO_MAPPINGS[test]="TestRepo"
REPO_CONFIGS[test]="./gradlew build|./gradlew test|./gradlew lint"
# Intentionally no REPO_IDE_CONFIGS[test] entry
EOF

  # Create a gradle project (should be detected as Android Studio)
  mkdir -p "$test_dir/gradle_repo"
  touch "$test_dir/gradle_repo/gradlew"

  local result=$(HOME="$test_dir" zsh -c '
    source "'$SCRIPT_DIR'/ci-helper.zsh"
    _load_ci_helper_impl
    detect_ide_info "'$test_dir'/gradle_repo" "test"
  ')

  if echo "$result" | grep -q "android-studio"; then
    pass "Falls back to heuristics when no IDE config"
  else
    fail "Expected android-studio detection" "Got: $result"
  fi
}

# Test 29: Empty REPO_MAPPINGS array
test_empty_repo_mappings() {
  test_start "Handle empty REPO_MAPPINGS array"

  local test_dir="$TEST_ROOT/test29"
  mkdir -p "$test_dir/.config/worktree-tools"

  # Create config with empty REPO_MAPPINGS
  cat > "$test_dir/.config/worktree-tools/config.zsh" << 'EOF'
[[ -z ${(t)REPO_MAPPINGS} ]] && declare -gA REPO_MAPPINGS
[[ -z ${(t)REPO_CONFIGS} ]] && declare -gA REPO_CONFIGS
# REPO_MAPPINGS is declared but empty
REPO_CONFIGS[standalone-repo]="npm build|npm test|npm lint"
EOF

  # Test getting config directly without mappings
  local result=$(HOME="$test_dir" zsh -c '
    source "'$SCRIPT_DIR'/ci-helper.zsh"
    _load_ci_helper_impl
    get_repo_config "standalone-repo"
  ')

  if echo "$result" | grep -q "npm build"; then
    pass "Works with empty REPO_MAPPINGS array"
  else
    fail "Config retrieval failed with empty mappings" "$result"
  fi
}

# =============================================================================
# Nested Worktree Tests
# =============================================================================

# Test 30: Nested worktree path resolution
test_nested_worktree_path_resolution() {
  test_start "Nested worktree path resolution"

  local test_dir="$TEST_ROOT/test30"
  mkdir -p "$test_dir/.config/worktree-tools"

  # Create config WITH nested worktree configuration
  cat > "$test_dir/.config/worktree-tools/config.zsh" <<EOF
[[ -z \${(t)REPO_MAPPINGS} ]] && declare -gA REPO_MAPPINGS
[[ -z \${(t)REPO_NESTED_WORKTREES} ]] && declare -gA REPO_NESTED_WORKTREES
REPO_MAPPINGS[nested]="NestedRepo"
REPO_NESTED_WORKTREES[nested]="NestedRepo"
BASE_DEV_PATH="$test_dir"
WORKTREES_PATH="$test_dir/worktrees"
EOF

  # Test path resolution for nested repo
  local result=$(HOME="$test_dir" zsh -c '
    source "'$SCRIPT_DIR'/git-worktree-helper.zsh"
    _load_git_worktree_impl
    paths=$(resolve_worktree_paths "NestedRepo" "feature" "nested")
    outer=${paths%%|*}
    inner=${paths##*|}
    echo "OUTER:$outer"
    echo "INNER:$inner"
  ')

  local outer=$(echo "$result" | grep "^OUTER:" | cut -d: -f2)
  local inner=$(echo "$result" | grep "^INNER:" | cut -d: -f2)

  if [[ "$outer" == "$test_dir/worktrees/NestedRepo-feature" && \
        "$inner" == "$test_dir/worktrees/NestedRepo-feature/NestedRepo" ]]; then
    pass "Nested worktree paths resolved correctly"
  else
    fail "Path resolution incorrect" "Outer: $outer, Inner: $inner"
  fi
}

# Test 31: Non-nested worktree path resolution (backward compat)
test_non_nested_worktree_path_resolution() {
  test_start "Non-nested worktree path resolution (backward compat)"

  local test_dir="$TEST_ROOT/test31"
  mkdir -p "$test_dir/.config/worktree-tools"

  # Create config WITHOUT nested worktree configuration
  cat > "$test_dir/.config/worktree-tools/config.zsh" <<EOF
[[ -z \${(t)REPO_MAPPINGS} ]] && declare -gA REPO_MAPPINGS
REPO_MAPPINGS[regular]="RegularRepo"
BASE_DEV_PATH="$test_dir"
WORKTREES_PATH="$test_dir/worktrees"
EOF

  # Test path resolution for regular repo
  local result=$(HOME="$test_dir" zsh -c '
    source "'$SCRIPT_DIR'/git-worktree-helper.zsh"
    _load_git_worktree_impl
    paths=$(resolve_worktree_paths "RegularRepo" "feature" "regular")
    outer=${paths%%|*}
    inner=${paths##*|}
    echo "OUTER:$outer"
    echo "INNER:$inner"
  ')

  local outer=$(echo "$result" | grep "^OUTER:" | cut -d: -f2)
  local inner=$(echo "$result" | grep "^INNER:" | cut -d: -f2)

  if [[ "$outer" == "$test_dir/worktrees/RegularRepo-feature" && \
        "$inner" == "$test_dir/worktrees/RegularRepo-feature" ]]; then
    pass "Non-nested worktree paths resolved correctly (backward compatible)"
  else
    fail "Path resolution incorrect" "Outer: $outer, Inner: $inner"
  fi
}

# Test 32: Create nested worktree
test_nested_worktree_creation() {
  test_start "Create nested worktree structure"

  local test_dir="$TEST_ROOT/test32"
  local bare_repo=$(setup_bare_repo_for_worktree_tests "$test_dir" "nested-repo")

  # Create config with nested worktree
  mkdir -p "$test_dir/.config/worktree-tools"
  cat > "$test_dir/.config/worktree-tools/config.zsh" <<EOF
[[ -z \${(t)REPO_MAPPINGS} ]] && declare -gA REPO_MAPPINGS
[[ -z \${(t)REPO_NESTED_WORKTREES} ]] && declare -gA REPO_NESTED_WORKTREES
REPO_MAPPINGS[nested]="nested-repo"
REPO_NESTED_WORKTREES[nested]="nested-repo"
BRANCH_PREFIX="testuser"
BASE_DEV_PATH="$test_dir"
BARE_REPOS_PATH="$test_dir/.repos"
WORKTREES_PATH="$test_dir/worktrees"
WORKTREE_TEMPLATES_PATH="$test_dir/worktree_templates"
EOF

  # Create nested worktree
  HOME="$test_dir" zsh -c '
    source "'$SCRIPT_DIR'/git-worktree-helper.zsh"
    _load_git_worktree_impl
    add_worktree "nested" "nested-feature" >/dev/null 2>&1
  '

  # Verify structure
  local outer_path="$test_dir/worktrees/nested-repo-nested-feature"
  local inner_path="$outer_path/nested-repo"

  if [[ -d "$outer_path" ]] && [[ -f "$inner_path/.git" ]] && [[ -f "$inner_path/README.md" ]]; then
    pass "Nested worktree structure created correctly"
  else
    fail "Nested worktree structure incorrect" "Outer: $outer_path, Inner: $inner_path"
  fi
}

# Test 33: List nested worktrees
test_nested_worktree_list() {
  test_start "List nested worktrees (display outer name)"

  local test_dir="$TEST_ROOT/test33"
  local bare_repo=$(setup_bare_repo_for_worktree_tests "$test_dir" "nested-repo")

  # Create config with nested worktree
  mkdir -p "$test_dir/.config/worktree-tools"
  cat > "$test_dir/.config/worktree-tools/config.zsh" <<EOF
[[ -z \${(t)REPO_MAPPINGS} ]] && declare -gA REPO_MAPPINGS
[[ -z \${(t)REPO_NESTED_WORKTREES} ]] && declare -gA REPO_NESTED_WORKTREES
REPO_MAPPINGS[nested]="nested-repo"
REPO_NESTED_WORKTREES[nested]="nested-repo"
BRANCH_PREFIX="testuser"
BASE_DEV_PATH="$test_dir"
BARE_REPOS_PATH="$test_dir/.repos"
WORKTREES_PATH="$test_dir/worktrees"
EOF

  # Create nested worktree
  HOME="$test_dir" zsh -c '
    source "'$SCRIPT_DIR'/git-worktree-helper.zsh"
    _load_git_worktree_impl
    add_worktree "nested" "list-test" >/dev/null 2>&1
  '

  # List worktrees
  local output=$(HOME="$test_dir" zsh -c '
    source "'$SCRIPT_DIR'/git-worktree-helper.zsh"
    _load_git_worktree_impl
    list_worktrees "nested" 2>&1
  ')

  # Should show outer directory name
  if echo "$output" | grep -q "nested-repo-list-test"; then
    pass "Nested worktree listed correctly (outer name shown)"
  else
    fail "List output incorrect" "$output"
  fi
}

# Test 34: Remove nested worktree
test_nested_worktree_removal() {
  test_start "Remove nested worktree (cleans up outer dir)"

  local test_dir="$TEST_ROOT/test34"
  local bare_repo=$(setup_bare_repo_for_worktree_tests "$test_dir" "nested-repo")

  # Create config with nested worktree
  mkdir -p "$test_dir/.config/worktree-tools"
  cat > "$test_dir/.config/worktree-tools/config.zsh" <<EOF
[[ -z \${(t)REPO_MAPPINGS} ]] && declare -gA REPO_MAPPINGS
[[ -z \${(t)REPO_NESTED_WORKTREES} ]] && declare -gA REPO_NESTED_WORKTREES
REPO_MAPPINGS[nested]="nested-repo"
REPO_NESTED_WORKTREES[nested]="nested-repo"
BRANCH_PREFIX="testuser"
BASE_DEV_PATH="$test_dir"
BARE_REPOS_PATH="$test_dir/.repos"
WORKTREES_PATH="$test_dir/worktrees"
EOF

  # Create and then remove nested worktree
  HOME="$test_dir" zsh -c '
    source "'$SCRIPT_DIR'/git-worktree-helper.zsh"
    _load_git_worktree_impl
    add_worktree "nested" "remove-test" >/dev/null 2>&1
    remove_worktree "nested" "nested-repo-remove-test" >/dev/null 2>&1
  '

  # Verify both inner and outer are removed
  local outer_path="$test_dir/worktrees/nested-repo-remove-test"
  if [[ ! -d "$outer_path" ]]; then
    pass "Nested worktree and outer directory removed"
  else
    fail "Nested worktree outer directory still exists" "Path: $outer_path"
  fi
}

# Test 35: Backward compatibility - existing tests work without nested config
test_backward_compatibility_no_nested_config() {
  test_start "Backward compatibility without nested config"

  local test_dir="$TEST_ROOT/test35"
  local bare_repo=$(setup_bare_repo_for_worktree_tests "$test_dir" "compat-repo")

  # Create config WITHOUT any nested configuration
  mkdir -p "$test_dir/.config/worktree-tools"
  cat > "$test_dir/.config/worktree-tools/config.zsh" <<EOF
[[ -z \${(t)REPO_MAPPINGS} ]] && declare -gA REPO_MAPPINGS
REPO_MAPPINGS[compat]="compat-repo"
BRANCH_PREFIX="testuser"
BASE_DEV_PATH="$test_dir"
BARE_REPOS_PATH="$test_dir/.repos"
WORKTREES_PATH="$test_dir/worktrees"
EOF

  # Create regular worktree
  HOME="$test_dir" zsh -c '
    source "'$SCRIPT_DIR'/git-worktree-helper.zsh"
    _load_git_worktree_impl
    add_worktree "compat" "compat-feature" >/dev/null 2>&1
  '

  # Verify regular (non-nested) structure
  local worktree_path="$test_dir/worktrees/compat-repo-compat-feature"
  if [[ -f "$worktree_path/.git" ]] && [[ -f "$worktree_path/README.md" ]]; then
    pass "Regular worktree works without nested config (backward compatible)"
  else
    fail "Regular worktree broken" "Path: $worktree_path"
  fi
}

# =============================================================================
# Main Test Runner
# =============================================================================

main() {
  echo "======================================"
  echo "Integration Tests for Zsh Plugins"
  echo "======================================"

  # Create test root directory
  TEST_ROOT=$(mktemp -d)
  echo "Test workspace: $TEST_ROOT"

  # Run config and helper tests
  test_config_loading
  test_shorthand_to_shorthand
  test_fullname_to_shorthand
  test_get_config_shorthand
  test_get_config_fullname
  test_get_modules
  test_get_ide_config
  test_empty_branch_prefix
  test_nonempty_branch_prefix
  test_plugin_loading
  test_unknown_repo
  test_platform_examples

  # Run IDE detection tests
  test_ide_detection_android
  test_ide_detection_swift_package
  test_ide_detection_xcode_workspace
  test_ide_detection_configured
  test_ide_detection_default

  # Run build command tests
  test_build_gradle_single_module
  test_build_gradle_multiple_modules
  test_build_gradle_no_modules

  # Run git worktree integration tests
  test_worktree_add_new_branch
  test_worktree_switch
  test_worktree_remove
  test_worktree_template_copy
  test_worktree_list
  test_branch_prefix_validation

  # Run edge case tests
  test_no_repo_mappings
  test_no_ide_config_fallback
  test_empty_repo_mappings

  # Run nested worktree tests
  test_nested_worktree_path_resolution
  test_non_nested_worktree_path_resolution
  test_nested_worktree_creation
  test_nested_worktree_list
  test_nested_worktree_removal
  test_backward_compatibility_no_nested_config

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

# Get script directory and repo root
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/.." && pwd)"
SCRIPT_DIR="$REPO_ROOT/src"

# Check if zsh is available
if ! command -v zsh &> /dev/null; then
  echo "ERROR: zsh not found. Please install zsh to run these tests."
  exit 1
fi

main
