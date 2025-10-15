#!/usr/bin/env bash
# Run all migration tests

set -uo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MIGRATIONS_DIR="$REPO_ROOT/migrations"

main() {
    echo -e "${BLUE}════════════════════════════════════════${NC}"
    echo -e "${BLUE}Migration Tests${NC}"
    echo -e "${BLUE}════════════════════════════════════════${NC}"
    echo ""

    # Check migrations directory exists
    if [[ ! -d "$MIGRATIONS_DIR" ]]; then
        echo -e "${RED}❌ Migrations directory not found: $MIGRATIONS_DIR${NC}"
        exit 1
    fi

    # Find all test scripts
    local test_scripts=()
    while IFS= read -r -d '' test_script; do
        test_scripts+=("$test_script")
    done < <(find "$MIGRATIONS_DIR" -maxdepth 1 -name "*_test.sh" -print0 | sort -z)

    if [[ ${#test_scripts[@]} -eq 0 ]]; then
        echo -e "${YELLOW}⚠️  No test scripts found${NC}"
        exit 0
    fi

    echo -e "${BLUE}Found ${#test_scripts[@]} test suite(s)${NC}"
    echo ""

    # Run each test script
    local total_passed=0
    local total_failed=0
    local suites_passed=0
    local suites_failed=0

    for test_script in "${test_scripts[@]}"; do
        local test_name=$(basename "$test_script" .sh)
        echo -e "${YELLOW}▶${NC} Running test suite: ${BLUE}$test_name${NC}"
        echo ""

        # Run test and capture output
        local output
        local exit_code=0
        output=$(bash "$test_script" 2>&1) || exit_code=$?

        echo "$output"
        echo ""

        # Parse results from output
        if [[ $exit_code -eq 0 ]]; then
            ((suites_passed++))
            # Extract pass/fail counts if available
            if echo "$output" | grep -q "Tests passed:"; then
                local passed=$(echo "$output" | grep "Tests passed:" | awk '{print $3}' | sed 's/\x1b\[[0-9;]*m//g')
                local failed=$(echo "$output" | grep "Tests failed:" | awk '{print $3}' | sed 's/\x1b\[[0-9;]*m//g')
                total_passed=$((total_passed + passed))
                total_failed=$((total_failed + failed))
            fi
        else
            ((suites_failed++))
            echo -e "${RED}❌ Test suite failed: $test_name${NC}"
            echo ""
        fi
    done

    # Summary
    echo -e "${BLUE}════════════════════════════════════════${NC}"
    echo -e "${BLUE}Test Summary${NC}"
    echo -e "${BLUE}════════════════════════════════════════${NC}"
    echo -e "Test suites run:    ${#test_scripts[@]}"
    echo -e "Suites passed:      ${GREEN}$suites_passed${NC}"

    if [[ $suites_failed -gt 0 ]]; then
        echo -e "Suites failed:      ${RED}$suites_failed${NC}"
    else
        echo -e "Suites failed:      ${GREEN}0${NC}"
    fi

    if [[ $total_passed -gt 0 ]] || [[ $total_failed -gt 0 ]]; then
        echo ""
        echo -e "Total tests passed: ${GREEN}$total_passed${NC}"
        if [[ $total_failed -gt 0 ]]; then
            echo -e "Total tests failed: ${RED}$total_failed${NC}"
        else
            echo -e "Total tests failed: ${GREEN}0${NC}"
        fi
    fi

    echo ""
    if [[ $suites_failed -gt 0 ]]; then
        echo -e "${RED}❌ Some test suites failed${NC}"
        exit 1
    else
        echo -e "${GREEN}✅ All test suites passed!${NC}"
        exit 0
    fi
}

main "$@"
