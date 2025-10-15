#!/usr/bin/env bash
# Tests for 001_shorthand_keys migration

set -uo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

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

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MIGRATION_SCRIPT="$SCRIPT_DIR/001_shorthand_keys.sh"

# Test 1: Migrate config with full repo names to shorthand
test_migrate_full_to_shorthand() {
    test_start "Migrate full repo names to shorthand"

    local test_dir=$(mktemp -d)
    local test_config="$test_dir/config.zsh"

    # Create old-format config
    cat > "$test_config" << 'EOF'
#!/usr/bin/env zsh
# Old format config

GIT_USERNAME="testuser"
BRANCH_PREFIX="testuser"
BASE_DEV_PATH="$HOME/dev"

[[ -z ${(t)REPO_MAPPINGS} ]] && declare -gA REPO_MAPPINGS
REPO_MAPPINGS[web]="MyApp-WebApp"
REPO_MAPPINGS[api]="MyApp-API"

REPO_CONFIGS[MyApp-WebApp]="npm run build|npm test|npm run lint"
REPO_CONFIGS[MyApp-API]="npm run build:api|npm test:api|npm run lint:api"

REPO_MODULES[MyApp-WebApp]="packages/ui packages/api"

BARE_REPOS_PATH="$BASE_DEV_PATH/.repos"
WORKTREES_PATH="$BASE_DEV_PATH/worktrees"
EOF

    # Run migration
    bash "$MIGRATION_SCRIPT" "$test_config" >/dev/null

    # Verify CONFIG_VERSION was added
    if grep -q "^CONFIG_VERSION=1" "$test_config"; then
        pass "CONFIG_VERSION=1 added"
    else
        fail "CONFIG_VERSION not added"
    fi

    # Verify REPO_CONFIGS keys were converted
    if grep -q 'REPO_CONFIGS\[web\]="npm run build|npm test|npm run lint"' "$test_config"; then
        pass "REPO_CONFIGS[MyApp-WebApp] → REPO_CONFIGS[web]"
    else
        fail "REPO_CONFIGS not migrated" "$(grep 'REPO_CONFIGS\[' "$test_config")"
    fi

    if grep -q 'REPO_CONFIGS\[api\]="npm run build:api|npm test:api|npm run lint:api"' "$test_config"; then
        pass "REPO_CONFIGS[MyApp-API] → REPO_CONFIGS[api]"
    else
        fail "REPO_CONFIGS[api] not migrated"
    fi

    # Verify REPO_MODULES keys were converted
    if grep -q 'REPO_MODULES\[web\]="packages/ui packages/api"' "$test_config"; then
        pass "REPO_MODULES[MyApp-WebApp] → REPO_MODULES[web]"
    else
        fail "REPO_MODULES not migrated"
    fi

    # Verify old keys are gone
    if ! grep -q 'REPO_CONFIGS\[MyApp-WebApp\]' "$test_config"; then
        pass "Old REPO_CONFIGS[MyApp-WebApp] removed"
    else
        fail "Old key still present"
    fi

    # Verify backup was created
    if ls "${test_config}.backup."* >/dev/null 2>&1; then
        pass "Backup created"
    else
        fail "No backup created"
    fi

    rm -rf "$test_dir"
}

# Test 2: Skip if already migrated
test_skip_if_already_migrated() {
    test_start "Skip migration if already at version 1"

    local test_dir=$(mktemp -d)
    local test_config="$test_dir/config.zsh"

    # Create already-migrated config
    cat > "$test_config" << 'EOF'
#!/usr/bin/env zsh
CONFIG_VERSION=1

[[ -z ${(t)REPO_MAPPINGS} ]] && declare -gA REPO_MAPPINGS
REPO_MAPPINGS[web]="MyApp-WebApp"

REPO_CONFIGS[web]="npm run build|npm test|npm run lint"
EOF

    local original_content=$(cat "$test_config")

    # Run migration
    local output=$(bash "$MIGRATION_SCRIPT" "$test_config" 2>&1)

    if echo "$output" | grep -q "Already at version 1"; then
        pass "Skipped already-migrated config"
    else
        fail "Did not skip already-migrated config"
    fi

    # Verify content unchanged
    local new_content=$(cat "$test_config")
    if [[ "$original_content" == "$new_content" ]]; then
        pass "Content unchanged after skip"
    else
        fail "Content changed despite skip"
    fi

    # Verify no backup created (since skipped)
    if ! ls "${test_config}.backup."* >/dev/null 2>&1; then
        pass "No backup created when skipped"
    else
        fail "Backup created despite skip"
    fi

    rm -rf "$test_dir"
}

# Test 3: Handle config with only shorthand keys (no migration needed)
test_handle_shorthand_only() {
    test_start "Handle config that only uses shorthand keys"

    local test_dir=$(mktemp -d)
    local test_config="$test_dir/config.zsh"

    # Create config with shorthand keys (but no version)
    cat > "$test_config" << 'EOF'
#!/usr/bin/env zsh

[[ -z ${(t)REPO_MAPPINGS} ]] && declare -gA REPO_MAPPINGS
REPO_MAPPINGS[web]="MyApp-WebApp"

REPO_CONFIGS[web]="npm run build|npm test|npm run lint"
EOF

    # Run migration
    bash "$MIGRATION_SCRIPT" "$test_config" >/dev/null

    # Should add version
    if grep -q "^CONFIG_VERSION=1" "$test_config"; then
        pass "CONFIG_VERSION=1 added"
    else
        fail "CONFIG_VERSION not added"
    fi

    # Should keep shorthand keys unchanged
    if grep -q 'REPO_CONFIGS\[web\]="npm run build|npm test|npm run lint"' "$test_config"; then
        pass "Shorthand keys preserved"
    else
        fail "Shorthand keys changed"
    fi

    rm -rf "$test_dir"
}

# Test 4: Handle mixed keys (some full, some shorthand)
test_handle_mixed_keys() {
    test_start "Handle mixed full and shorthand keys"

    local test_dir=$(mktemp -d)
    local test_config="$test_dir/config.zsh"

    cat > "$test_config" << 'EOF'
#!/usr/bin/env zsh

[[ -z ${(t)REPO_MAPPINGS} ]] && declare -gA REPO_MAPPINGS
REPO_MAPPINGS[web]="MyApp-WebApp"
REPO_MAPPINGS[api]="MyApp-API"

REPO_CONFIGS[MyApp-WebApp]="npm run build|npm test|npm run lint"
REPO_CONFIGS[api]="npm run build:api|npm test:api|npm run lint:api"
EOF

    bash "$MIGRATION_SCRIPT" "$test_config" >/dev/null

    # Full name should be converted
    if grep -q 'REPO_CONFIGS\[web\]="npm run build|npm test|npm run lint"' "$test_config"; then
        pass "Full name converted to shorthand"
    else
        fail "Full name not converted"
    fi

    # Shorthand should be preserved
    if grep -q 'REPO_CONFIGS\[api\]="npm run build:api|npm test:api|npm run lint:api"' "$test_config"; then
        pass "Existing shorthand preserved"
    else
        fail "Shorthand key changed"
    fi

    rm -rf "$test_dir"
}

# Test 5: Add missing array declarations
test_add_missing_declarations() {
    test_start "Add missing array declarations"

    local test_dir=$(mktemp -d)
    local test_config="$test_dir/config.zsh"

    # Create config with array assignments but no declarations
    cat > "$test_config" << 'EOF'
#!/usr/bin/env zsh

GIT_USERNAME="testuser"
BRANCH_PREFIX="testuser"
BASE_DEV_PATH="$HOME/dev"

[[ -z ${(t)REPO_MAPPINGS} ]] && declare -gA REPO_MAPPINGS
REPO_MAPPINGS[web]="MyApp-WebApp"
REPO_MAPPINGS[api]="MyApp-API"

REPO_CONFIGS[MyApp-WebApp]="npm run build|npm test|npm run lint"
REPO_CONFIGS[MyApp-API]="npm run build:api|npm test:api|npm run lint:api"

REPO_MODULES[MyApp-WebApp]="packages/ui packages/api"

REPO_IDE_CONFIGS[MyApp-WebApp]="vscode||"

BARE_REPOS_PATH="$BASE_DEV_PATH/.repos"
WORKTREES_PATH="$BASE_DEV_PATH/worktrees"
EOF

    # Run migration
    bash "$MIGRATION_SCRIPT" "$test_config" >/dev/null

    # Verify REPO_CONFIGS declaration was added
    if grep -q '\[\[ -z \${(t)REPO_CONFIGS} \]\] && declare -gA REPO_CONFIGS' "$test_config"; then
        pass "REPO_CONFIGS declaration added"
    else
        fail "REPO_CONFIGS declaration not added"
    fi

    # Verify REPO_MODULES declaration was added
    if grep -q '\[\[ -z \${(t)REPO_MODULES} \]\] && declare -gA REPO_MODULES' "$test_config"; then
        pass "REPO_MODULES declaration added"
    else
        fail "REPO_MODULES declaration not added"
    fi

    # Verify REPO_IDE_CONFIGS declaration was added
    if grep -q '\[\[ -z \${(t)REPO_IDE_CONFIGS} \]\] && declare -gA REPO_IDE_CONFIGS' "$test_config"; then
        pass "REPO_IDE_CONFIGS declaration added"
    else
        fail "REPO_IDE_CONFIGS declaration not added"
    fi

    # Verify declarations come before assignments
    local config_content=$(cat "$test_config")

    # Extract line numbers
    local configs_decl_line=$(grep -n 'declare -gA REPO_CONFIGS' "$test_config" | cut -d: -f1)
    local configs_assign_line=$(grep -n '^REPO_CONFIGS\[' "$test_config" | head -1 | cut -d: -f1)

    if [[ $configs_decl_line -lt $configs_assign_line ]]; then
        pass "REPO_CONFIGS declaration comes before assignment"
    else
        fail "REPO_CONFIGS declaration should come before assignment"
    fi

    rm -rf "$test_dir"
}

# Main
main() {
    echo "======================================"
    echo "Tests for 001_shorthand_keys migration"
    echo "======================================"

    test_migrate_full_to_shorthand
    test_skip_if_already_migrated
    test_handle_shorthand_only
    test_handle_mixed_keys
    test_add_missing_declarations

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

main
