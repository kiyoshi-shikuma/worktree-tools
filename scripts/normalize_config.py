#!/usr/bin/env python3
"""
Normalize user config to match example format while preserving values.

This script:
1. Extracts values from user's config
2. Uses example config as template
3. Replaces values while preserving structure/comments
"""

import re
import sys
from pathlib import Path
from datetime import datetime
from typing import Dict, List, Tuple


class ConfigNormalizer:
    """Normalizes user config to match example format."""

    def __init__(self, user_config: str, example_config: str):
        self.user_config = user_config
        self.example_config = example_config
        self.user_values = self._extract_user_values(user_config)

    def _extract_user_values(self, config: str) -> Dict:
        """Extract all user values from config."""
        values = {
            'simple': {},
            'mappings': [],
            'ide_configs': [],
            'repo_configs': [],
            'repo_modules': []
        }

        # Extract simple variables
        for var in ['GIT_USERNAME', 'BRANCH_PREFIX', 'BASE_DEV_PATH', 'CONFIG_VERSION']:
            pattern = rf'^{var}=(.*)$'
            match = re.search(pattern, config, re.MULTILINE)
            if match:
                values['simple'][var] = match.group(1)

        # Extract REPO_MAPPINGS entries and build reverse lookup
        pattern = r'^REPO_MAPPINGS\[([^\]]+)\]="([^"]*)"'
        values['mappings'] = re.findall(pattern, config, re.MULTILINE)

        # Build reverse mapping: full_name -> shorthand
        full_to_short = {}
        for shorthand, full_name in values['mappings']:
            full_to_short[full_name] = shorthand

        # Extract REPO_IDE_CONFIGS entries (convert full names to shorthand)
        pattern = r'^REPO_IDE_CONFIGS\[([^\]]+)\]="([^"]*)"'
        ide_configs_raw = re.findall(pattern, config, re.MULTILINE)
        for key, value in ide_configs_raw:
            # Use shorthand if key is a full name, otherwise use as-is
            final_key = full_to_short.get(key, key)
            values['ide_configs'].append((final_key, value))

        # Extract REPO_CONFIGS entries (convert full names to shorthand)
        pattern = r'^REPO_CONFIGS\[([^\]]+)\]="([^"]*)"'
        repo_configs_raw = re.findall(pattern, config, re.MULTILINE)
        for key, value in repo_configs_raw:
            final_key = full_to_short.get(key, key)
            values['repo_configs'].append((final_key, value))

        # Extract REPO_MODULES entries (convert full names to shorthand)
        pattern = r'^REPO_MODULES\[([^\]]+)\]="([^"]*)"'
        repo_modules_raw = re.findall(pattern, config, re.MULTILINE)
        for key, value in repo_modules_raw:
            final_key = full_to_short.get(key, key)
            values['repo_modules'].append((final_key, value))

        return values

    def normalize(self) -> str:
        """Normalize config using example as template."""
        lines = self.example_config.split('\n')
        result = []
        i = 0

        while i < len(lines):
            line = lines[i]

            # Replace simple variables
            for var, value in self.user_values['simple'].items():
                if line.startswith(f'{var}='):
                    line = f'{var}={value}'
                    break

            # Handle REPO_MAPPINGS
            if '[[ -z ${(t)REPO_MAPPINGS}' in line:
                result.append(line)
                i += 1

                # Add user's mappings
                if self.user_values['mappings']:
                    result.append('')
                    for key, value in self.user_values['mappings']:
                        result.append(f'REPO_MAPPINGS[{key}]="{value}"')

                # Skip everything until next section header (===)
                while i < len(lines):
                    next_line = lines[i]
                    # If we hit a section header, stop
                    if '===' in next_line:
                        break
                    # Skip this line (could be comment, example, blank, etc.)
                    i += 1
                continue

            # Handle IDE configs section
            if line.startswith('# Optional: IDE configuration'):
                result.append(line)
                i += 1

                # Add everything until we see example REPO_IDE_CONFIGS
                while i < len(lines) and not lines[i].startswith('# REPO_IDE_CONFIGS['):
                    result.append(lines[i])
                    i += 1

                # Add user's IDE configs
                if self.user_values['ide_configs']:
                    result.append('')
                    for key, value in self.user_values['ide_configs']:
                        result.append(f'REPO_IDE_CONFIGS[{key}]="{value}"')
                    result.append('')

                # Skip example IDE config lines
                while i < len(lines) and lines[i].startswith('# REPO_IDE_CONFIGS['):
                    i += 1
                continue

            # Handle CI commands section
            if line.startswith('# Optional: CI commands'):
                result.append(line)
                i += 1

                # Add everything until we see example REPO_CONFIGS
                while i < len(lines) and not (lines[i].startswith('# Android example:') or lines[i].startswith('# REPO_CONFIGS[')):
                    result.append(lines[i])
                    i += 1

                # Add user's repo configs
                if self.user_values['repo_configs']:
                    result.append('')
                    for key, value in self.user_values['repo_configs']:
                        result.append(f'REPO_CONFIGS[{key}]="{value}"')
                    result.append('')

                # Skip example config lines (Android/iOS/Web examples)
                while i < len(lines):
                    line_check = lines[i]
                    if line_check.startswith('# Android example:') or \
                       line_check.startswith('# iOS example:') or \
                       line_check.startswith('# Web example:') or \
                       line_check.startswith('# REPO_CONFIGS['):
                        i += 1
                        continue
                    if line_check.startswith('# ==='):
                        break
                    if line_check.strip() == '' and i+1 < len(lines) and lines[i+1].startswith('# ==='):
                        i += 1
                        break
                    break
                continue

            # Handle modular builds section
            if line.startswith('# Optional: Modular builds'):
                result.append(line)
                i += 1

                # Add everything until we see example REPO_MODULES
                while i < len(lines) and not (lines[i].startswith('# Android modules:') or lines[i].startswith('# REPO_MODULES[')):
                    result.append(lines[i])
                    i += 1

                # Add user's modules
                if self.user_values['repo_modules']:
                    result.append('')
                    for key, value in self.user_values['repo_modules']:
                        result.append(f'REPO_MODULES[{key}]="{value}"')
                    result.append('')

                # Skip example module lines
                while i < len(lines):
                    line_check = lines[i]
                    if line_check.startswith('# Android modules:') or \
                       line_check.startswith('# iOS modules:') or \
                       line_check.startswith('# Web packages:') or \
                       line_check.startswith('# REPO_MODULES['):
                        i += 1
                        continue
                    if line_check.startswith('# ==='):
                        break
                    if line_check.strip() == '' and i+1 < len(lines) and lines[i+1].startswith('# ==='):
                        i += 1
                        break
                    break
                continue

            result.append(line)
            i += 1

        return '\n'.join(result)


def main():
    if len(sys.argv) != 2:
        print("Usage: normalize_config.py <config-file>")
        print()
        print("Normalizes config to match example format while keeping your values.")
        print("Creates backup before modifying.")
        sys.exit(1)

    config_path = Path(sys.argv[1])

    if not config_path.exists():
        print(f"❌ Config file not found: {config_path}")
        sys.exit(1)

    # Find example config
    script_dir = Path(__file__).parent
    repo_root = script_dir.parent
    example_path = repo_root / "src" / "config.zsh.example"

    if not example_path.exists():
        print(f"❌ Example config not found: {example_path}")
        sys.exit(1)

    print("🔄 Normalizing config to match example format...")
    print(f"📁 Config: {config_path}")
    print(f"📋 Template: {example_path}")
    print()

    # Create backup
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    backup_path = config_path.parent / f"{config_path.name}.normalized.backup.{timestamp}"
    backup_path.write_text(config_path.read_text())
    print(f"💾 Backup created: {backup_path}")

    # Read configs
    user_config = config_path.read_text()
    example_config = example_path.read_text()

    # Normalize
    normalizer = ConfigNormalizer(user_config, example_config)
    normalized = normalizer.normalize()

    # Write back
    config_path.write_text(normalized)

    print("✅ Config normalized!")
    print("💡 Backup available at:", backup_path)
    print()
    print("📝 Your actual repository configurations have been preserved.")
    print("🎨 Comments and formatting now match the example config.")


if __name__ == '__main__':
    main()
