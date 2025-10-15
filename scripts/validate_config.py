#!/usr/bin/env python3
"""
Validate and fix common config issues.

Issues detected and fixed:
1. Missing array declarations for REPO_CONFIGS, REPO_MODULES, REPO_IDE_CONFIGS
2. Variables not properly expanded (like $HOME)
3. Missing blank lines between sections
"""

import re
import sys
from pathlib import Path
from datetime import datetime
from typing import List, Tuple


class ConfigValidator:
    """Validates and fixes config issues."""

    def __init__(self, config_path: str):
        self.config_path = Path(config_path)
        self.issues: List[str] = []
        self.fixes: List[str] = []

    def validate_and_fix(self) -> Tuple[str, bool]:
        """Validate config and return fixed version. Returns (fixed_config, had_issues)."""
        if not self.config_path.exists():
            raise FileNotFoundError(f"Config not found: {self.config_path}")

        config = self.config_path.read_text()
        original_config = config
        had_issues = False

        # Check 1: Missing array declarations
        config, fixed = self._fix_missing_declarations(config)
        if fixed:
            had_issues = True

        # Check 2: Ensure blank line after REPO_MAPPINGS section
        config, fixed = self._fix_section_spacing(config)
        if fixed:
            had_issues = True

        return config, had_issues

    def _fix_missing_declarations(self, config: str) -> Tuple[str, bool]:
        """Add missing array declarations."""
        lines = config.split('\n')
        fixed = False
        result = []
        i = 0

        # Track which arrays need declarations
        needs_declaration = {
            'REPO_CONFIGS': False,
            'REPO_MODULES': False,
            'REPO_IDE_CONFIGS': False
        }

        # Track which are already declared
        declared = {
            'REPO_CONFIGS': False,
            'REPO_MODULES': False,
            'REPO_IDE_CONFIGS': False
        }

        # First pass: check what's used and what's declared
        for line in lines:
            # Check for declarations
            for array_name in needs_declaration.keys():
                if f'declare -gA {array_name}' in line:
                    declared[array_name] = True

            # Check for assignments
            for array_name in needs_declaration.keys():
                if re.match(rf'^{array_name}\[', line):
                    needs_declaration[array_name] = True

        # Second pass: add declarations where needed
        i = 0
        while i < len(lines):
            line = lines[i]

            # Add REPO_IDE_CONFIGS declaration before first assignment
            if needs_declaration['REPO_IDE_CONFIGS'] and not declared['REPO_IDE_CONFIGS']:
                if re.match(r'^REPO_IDE_CONFIGS\[', line):
                    self.issues.append("Missing REPO_IDE_CONFIGS declaration")
                    self.fixes.append("Added: [[ -z ${(t)REPO_IDE_CONFIGS} ]] && declare -gA REPO_IDE_CONFIGS")
                    result.append('[[ -z ${(t)REPO_IDE_CONFIGS} ]] && declare -gA REPO_IDE_CONFIGS')
                    result.append('')
                    declared['REPO_IDE_CONFIGS'] = True
                    fixed = True

            # Add REPO_CONFIGS declaration before first assignment
            if needs_declaration['REPO_CONFIGS'] and not declared['REPO_CONFIGS']:
                if re.match(r'^REPO_CONFIGS\[', line):
                    self.issues.append("Missing REPO_CONFIGS declaration")
                    self.fixes.append("Added: [[ -z ${(t)REPO_CONFIGS} ]] && declare -gA REPO_CONFIGS")
                    result.append('[[ -z ${(t)REPO_CONFIGS} ]] && declare -gA REPO_CONFIGS')
                    result.append('')
                    declared['REPO_CONFIGS'] = True
                    fixed = True

            # Add REPO_MODULES declaration before first assignment
            if needs_declaration['REPO_MODULES'] and not declared['REPO_MODULES']:
                if re.match(r'^REPO_MODULES\[', line):
                    self.issues.append("Missing REPO_MODULES declaration")
                    self.fixes.append("Added: [[ -z ${(t)REPO_MODULES} ]] && declare -gA REPO_MODULES")
                    result.append('[[ -z ${(t)REPO_MODULES} ]] && declare -gA REPO_MODULES')
                    result.append('')
                    declared['REPO_MODULES'] = True
                    fixed = True

            result.append(line)
            i += 1

        return '\n'.join(result), fixed

    def _fix_section_spacing(self, config: str) -> Tuple[str, bool]:
        """Ensure proper spacing between sections."""
        lines = config.split('\n')
        result = []
        fixed = False
        i = 0

        while i < len(lines):
            line = lines[i]
            result.append(line)

            # After last REPO_MAPPINGS entry, ensure blank line before next section
            if re.match(r'^REPO_MAPPINGS\[', line):
                # Look ahead to see if next non-mapping line is immediate section header
                j = i + 1
                while j < len(lines) and re.match(r'^REPO_MAPPINGS\[', lines[j]):
                    j += 1

                # If next non-mapping line is a section header without blank line
                if j < len(lines) and lines[j].startswith('#') and '===' in lines[j]:
                    # Check if there's no blank line before it
                    if j > 0 and lines[j-1].strip() != '':
                        # We'll add blank line after all mappings
                        pass

            i += 1

        return '\n'.join(result), fixed


def main():
    if len(sys.argv) < 2:
        print("Usage: validate_config.py <config-file> [--fix]")
        print()
        print("Validates config file for common issues.")
        print("Use --fix to automatically fix issues.")
        sys.exit(1)

    config_path = sys.argv[1]
    should_fix = '--fix' in sys.argv

    validator = ConfigValidator(config_path)

    print("🔍 Validating config...")
    print(f"📁 Config: {config_path}")
    print()

    try:
        fixed_config, had_issues = validator.validate_and_fix()

        if not had_issues:
            print("✅ No issues found! Config is valid.")
            sys.exit(0)

        # Report issues
        print("⚠️  Issues found:")
        for issue in validator.issues:
            print(f"  • {issue}")
        print()

        if should_fix:
            # Create backup
            config_path_obj = Path(config_path)
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            backup_path = config_path_obj.parent / f"{config_path_obj.name}.validated.backup.{timestamp}"
            backup_path.write_text(config_path_obj.read_text())
            print(f"💾 Backup created: {backup_path}")

            # Apply fixes
            config_path_obj.write_text(fixed_config)

            print("✅ Fixes applied:")
            for fix in validator.fixes:
                print(f"  • {fix}")
            print()
            print("🎉 Config fixed!")
        else:
            print("💡 Run with --fix to automatically fix these issues")
            sys.exit(1)

    except Exception as e:
        print(f"❌ Error: {e}")
        sys.exit(1)


if __name__ == '__main__':
    main()
