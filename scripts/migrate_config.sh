#!/usr/bin/env bash
# Run all migrations on user config file

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Default config path
DEFAULT_CONFIG="$HOME/.config/worktree-tools/config.zsh"

usage() {
    cat << EOF
Usage: $0 [config-file]

Runs all migrations on the specified config file.

Arguments:
  config-file    Path to config file (default: ~/.config/worktree-tools/config.zsh)

Examples:
  $0                          # Migrate default config
  $0 ~/my-config.zsh          # Migrate specific config
EOF
}

main() {
    # Parse arguments
    local config_file="${1:-$DEFAULT_CONFIG}"

    if [[ "$config_file" == "-h" ]] || [[ "$config_file" == "--help" ]]; then
        usage
        exit 0
    fi

    # Validate config file exists
    if [[ ! -f "$config_file" ]]; then
        echo -e "${RED}❌ Config file not found: $config_file${NC}"
        exit 1
    fi

    echo -e "${BLUE}════════════════════════════════════════${NC}"
    echo -e "${BLUE}Config Migration Tool${NC}"
    echo -e "${BLUE}════════════════════════════════════════${NC}"
    echo ""
    echo "Config file: $config_file"
    echo ""

    # Get script directory
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
    MIGRATIONS_DIR="$REPO_ROOT/migrations"

    # Check migrations directory exists
    if [[ ! -d "$MIGRATIONS_DIR" ]]; then
        echo -e "${RED}❌ Migrations directory not found: $MIGRATIONS_DIR${NC}"
        exit 1
    fi

    # Find all migration scripts (exclude test files)
    local migrations=()
    while IFS= read -r -d '' migration; do
        migrations+=("$migration")
    done < <(find "$MIGRATIONS_DIR" -maxdepth 1 -name "[0-9]*_*.sh" ! -name "*_test.sh" -print0 | sort -z)

    if [[ ${#migrations[@]} -eq 0 ]]; then
        echo -e "${YELLOW}⚠️  No migrations found${NC}"
        exit 0
    fi

    echo -e "${BLUE}Found ${#migrations[@]} migration(s)${NC}"
    echo ""

    # Run each migration
    local applied=0
    local skipped=0
    local failed=0

    for migration in "${migrations[@]}"; do
        local migration_name=$(basename "$migration" .sh)
        echo -e "${YELLOW}▶${NC} Running migration: ${BLUE}$migration_name${NC}"

        # Capture output to check if migration was applied or skipped
        local output
        if output=$(bash "$migration" "$config_file" 2>&1); then
            echo "$output"
            # Check if migration was skipped
            if echo "$output" | grep -q "skipping\|Already at version"; then
                ((skipped++))
            else
                ((applied++))
            fi
        else
            echo "$output"
            echo -e "${RED}❌ Migration failed: $migration_name${NC}"
            ((failed++))
        fi
        echo ""
    done

    # Summary
    echo -e "${BLUE}════════════════════════════════════════${NC}"
    echo -e "${BLUE}Migration Summary${NC}"
    echo -e "${BLUE}════════════════════════════════════════${NC}"
    echo -e "Total migrations: ${#migrations[@]}"
    echo -e "Applied:          ${GREEN}$applied${NC}"
    echo -e "Skipped:          ${YELLOW}$skipped${NC}"

    if [[ $failed -gt 0 ]]; then
        echo -e "Failed:           ${RED}$failed${NC}"
        echo ""
        echo -e "${RED}❌ Some migrations failed${NC}"
        exit 1
    else
        echo -e "Failed:           ${GREEN}0${NC}"
        echo ""
        echo -e "${GREEN}✅ All migrations completed successfully${NC}"
        exit 0
    fi
}

main "$@"
