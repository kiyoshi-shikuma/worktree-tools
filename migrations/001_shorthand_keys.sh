#!/usr/bin/env bash
# Migration: Convert full repo name keys to shorthand keys
# From: REPO_CONFIGS[Full-Repo-Name]="..."
# To:   REPO_CONFIGS[shorthand]="..."

set -euo pipefail

migrate_to_shorthand() {
    local config_file="$1"

    if [[ ! -f "$config_file" ]]; then
        echo "❌ Config file not found: $config_file"
        return 1
    fi

    # Check if already migrated
    if grep -q "^CONFIG_VERSION=1" "$config_file"; then
        echo "✅ Already at version 1, skipping"
        return 0
    fi

    echo "🔄 Migrating config to use shorthand keys..."

    # Create backup
    cp "$config_file" "${config_file}.backup.$(date +%Y%m%d_%H%M%S)"
    echo "📋 Backup created: ${config_file}.backup.*"

    # Extract REPO_MAPPINGS to build fullname->shorthand mapping file
    # Use zsh to parse the config and output mappings
    local mappings_file="${config_file}.mappings.tmp"
    zsh -c "
        source '$config_file' 2>/dev/null || true
        for short full in \${(kv)REPO_MAPPINGS[@]}; do
            echo \"\$full:\$short\"
        done
    " > "$mappings_file"

    # Create temp file for the migrated config
    local temp_file="${config_file}.migrating"
    cp "$config_file" "$temp_file"

    # For each mapping, replace full names with shorthand in config arrays
    while IFS=: read -r full_name shorthand; do
        # Skip empty lines
        [[ -z "${full_name}" ]] && continue

        # For each config array type
        for array_name in REPO_CONFIGS REPO_MODULES REPO_IDE_CONFIGS; do
            # Check if this full name is used as a key
            if grep -q "^[[:space:]]*${array_name}\[${full_name}\]" "${temp_file}"; then
                echo "  🔄 $array_name[${full_name}] → $array_name[${shorthand}]"

                # Escape special characters for sed
                local escaped_full
                escaped_full=$(printf '%s\n' "${full_name}" | sed 's/[[\.*^$()+?{|]/\\&/g')
                local escaped_short
                escaped_short=$(printf '%s\n' "${shorthand}" | sed 's/[\/&]/\\&/g')

                # Replace the key
                sed -i '' "s/^\\([[:space:]]*${array_name}\\[\\)${escaped_full}\\(\\]\\)/\\1${escaped_short}\\2/" "${temp_file}"
            fi
        done
    done < "${mappings_file}"

    # Clean up mappings file
    rm -f "$mappings_file"

    # Add array declarations if missing
    for array_name in REPO_CONFIGS REPO_MODULES REPO_IDE_CONFIGS; do
        # Check if array is used but not declared
        if grep -q "^[[:space:]]*${array_name}\[" "$temp_file" && \
           ! grep -q "declare -gA ${array_name}" "$temp_file"; then
            echo "  ✨ Adding ${array_name} declaration"

            # Find the first occurrence of the array and add declaration before it
            awk -v array="$array_name" '
                !inserted && $0 ~ "^[[:space:]]*" array "\\[" {
                    print "[[ -z ${(t)" array "} ]] && declare -gA " array
                    print ""
                    inserted=1
                }
                { print }
            ' "$temp_file" > "${temp_file}.declared"
            mv "${temp_file}.declared" "$temp_file"
        fi
    done

    # Add CONFIG_VERSION=1 at the top (after shebang and initial comments)
    if ! grep -q "^CONFIG_VERSION=" "$temp_file"; then
        # Find first non-comment, non-empty line and insert before it
        awk '
            BEGIN { inserted=0 }
            /^#!/ { print; next }
            /^[[:space:]]*#/ { print; next }
            /^[[:space:]]*$/ { print; next }
            !inserted {
                print "# Config version (for migrations)"
                print "CONFIG_VERSION=1"
                print ""
                inserted=1
            }
            { print }
        ' "$temp_file" > "${temp_file}.versioned"
        mv "${temp_file}.versioned" "$temp_file"
    fi

    # Replace original with migrated version
    mv "$temp_file" "$config_file"

    echo "✅ Migration complete! Config now at version 1"
    echo "💡 Backup available at: ${config_file}.backup.*"

    return 0
}

# If called directly (not sourced), run migration
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [[ $# -lt 1 ]]; then
        echo "Usage: $0 <config-file>"
        exit 1
    fi
    migrate_to_shorthand "$1"
fi
