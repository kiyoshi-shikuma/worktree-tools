#!/usr/bin/env python3
"""Tests for validate_config.py"""

import unittest
from validate_config import ConfigValidator
from pathlib import Path
import tempfile


class TestConfigValidator(unittest.TestCase):
    """Test config validation."""

    def test_missing_repo_ide_configs_declaration(self):
        """Test adding missing REPO_IDE_CONFIGS declaration."""
        config = '''#!/usr/bin/env zsh
[[ -z ${(t)REPO_MAPPINGS} ]] && declare -gA REPO_MAPPINGS

REPO_IDE_CONFIGS[acmd]="android-studio||"
REPO_IDE_CONFIGS[icmd]="xcode-workspace|App.xcworkspace|"
'''

        with tempfile.NamedTemporaryFile(mode='w', suffix='.zsh', delete=False) as f:
            f.write(config)
            f.flush()

            validator = ConfigValidator(f.name)
            fixed, had_issues = validator.validate_and_fix()

            Path(f.name).unlink()

        self.assertTrue(had_issues)
        self.assertIn('[[ -z ${(t)REPO_IDE_CONFIGS} ]] && declare -gA REPO_IDE_CONFIGS', fixed)
        self.assertIn('Missing REPO_IDE_CONFIGS declaration', validator.issues)

    def test_missing_repo_configs_declaration(self):
        """Test adding missing REPO_CONFIGS declaration."""
        config = '''#!/usr/bin/env zsh
[[ -z ${(t)REPO_MAPPINGS} ]] && declare -gA REPO_MAPPINGS

REPO_CONFIGS[acmd]="./gradlew build|./gradlew test|./gradlew lint"
'''

        with tempfile.NamedTemporaryFile(mode='w', suffix='.zsh', delete=False) as f:
            f.write(config)
            f.flush()

            validator = ConfigValidator(f.name)
            fixed, had_issues = validator.validate_and_fix()

            Path(f.name).unlink()

        self.assertTrue(had_issues)
        self.assertIn('[[ -z ${(t)REPO_CONFIGS} ]] && declare -gA REPO_CONFIGS', fixed)

    def test_missing_repo_modules_declaration(self):
        """Test adding missing REPO_MODULES declaration."""
        config = '''#!/usr/bin/env zsh
[[ -z ${(t)REPO_MAPPINGS} ]] && declare -gA REPO_MAPPINGS

REPO_MODULES[acmd]="core-module feature-module"
'''

        with tempfile.NamedTemporaryFile(mode='w', suffix='.zsh', delete=False) as f:
            f.write(config)
            f.flush()

            validator = ConfigValidator(f.name)
            fixed, had_issues = validator.validate_and_fix()

            Path(f.name).unlink()

        self.assertTrue(had_issues)
        self.assertIn('[[ -z ${(t)REPO_MODULES} ]] && declare -gA REPO_MODULES', fixed)

    def test_all_missing_declarations(self):
        """Test adding all missing declarations at once."""
        config = '''#!/usr/bin/env zsh
[[ -z ${(t)REPO_MAPPINGS} ]] && declare -gA REPO_MAPPINGS
REPO_MAPPINGS[acmd]="App-Android"

REPO_IDE_CONFIGS[acmd]="android-studio||"

REPO_CONFIGS[acmd]="./gradlew build|./gradlew test|./gradlew lint"

REPO_MODULES[acmd]="core feature"
'''

        with tempfile.NamedTemporaryFile(mode='w', suffix='.zsh', delete=False) as f:
            f.write(config)
            f.flush()

            validator = ConfigValidator(f.name)
            fixed, had_issues = validator.validate_and_fix()

            Path(f.name).unlink()

        self.assertTrue(had_issues)
        self.assertEqual(len(validator.issues), 3)

        # Check all declarations were added before their first use
        self.assertIn('[[ -z ${(t)REPO_IDE_CONFIGS} ]] && declare -gA REPO_IDE_CONFIGS', fixed)
        self.assertIn('[[ -z ${(t)REPO_CONFIGS} ]] && declare -gA REPO_CONFIGS', fixed)
        self.assertIn('[[ -z ${(t)REPO_MODULES} ]] && declare -gA REPO_MODULES', fixed)

        # Verify declarations come before assignments
        lines = fixed.split('\n')
        ide_decl_idx = None
        ide_assign_idx = None
        configs_decl_idx = None
        configs_assign_idx = None
        modules_decl_idx = None
        modules_assign_idx = None

        for i, line in enumerate(lines):
            if 'declare -gA REPO_IDE_CONFIGS' in line:
                ide_decl_idx = i
            elif line.startswith('REPO_IDE_CONFIGS['):
                if ide_assign_idx is None:
                    ide_assign_idx = i
            elif 'declare -gA REPO_CONFIGS' in line:
                configs_decl_idx = i
            elif line.startswith('REPO_CONFIGS['):
                if configs_assign_idx is None:
                    configs_assign_idx = i
            elif 'declare -gA REPO_MODULES' in line:
                modules_decl_idx = i
            elif line.startswith('REPO_MODULES['):
                if modules_assign_idx is None:
                    modules_assign_idx = i

        self.assertIsNotNone(ide_decl_idx)
        self.assertIsNotNone(ide_assign_idx)
        self.assertLess(ide_decl_idx, ide_assign_idx, "REPO_IDE_CONFIGS declaration should come before assignment")

        self.assertIsNotNone(configs_decl_idx)
        self.assertIsNotNone(configs_assign_idx)
        self.assertLess(configs_decl_idx, configs_assign_idx, "REPO_CONFIGS declaration should come before assignment")

        self.assertIsNotNone(modules_decl_idx)
        self.assertIsNotNone(modules_assign_idx)
        self.assertLess(modules_decl_idx, modules_assign_idx, "REPO_MODULES declaration should come before assignment")

    def test_already_declared_arrays(self):
        """Test that already declared arrays are not duplicated."""
        config = '''#!/usr/bin/env zsh
[[ -z ${(t)REPO_MAPPINGS} ]] && declare -gA REPO_MAPPINGS
[[ -z ${(t)REPO_CONFIGS} ]] && declare -gA REPO_CONFIGS
[[ -z ${(t)REPO_MODULES} ]] && declare -gA REPO_MODULES
[[ -z ${(t)REPO_IDE_CONFIGS} ]] && declare -gA REPO_IDE_CONFIGS

REPO_CONFIGS[acmd]="./gradlew build|./gradlew test|./gradlew lint"
REPO_MODULES[acmd]="core feature"
REPO_IDE_CONFIGS[acmd]="android-studio||"
'''

        with tempfile.NamedTemporaryFile(mode='w', suffix='.zsh', delete=False) as f:
            f.write(config)
            f.flush()

            validator = ConfigValidator(f.name)
            fixed, had_issues = validator.validate_and_fix()

            Path(f.name).unlink()

        self.assertFalse(had_issues)
        self.assertEqual(len(validator.issues), 0)

    def test_no_assignments_no_issues(self):
        """Test config with no array assignments has no issues."""
        config = '''#!/usr/bin/env zsh
GIT_USERNAME="testuser"
BRANCH_PREFIX="testuser"
BASE_DEV_PATH="$HOME/dev"

[[ -z ${(t)REPO_MAPPINGS} ]] && declare -gA REPO_MAPPINGS
REPO_MAPPINGS[acmd]="App-Android"
'''

        with tempfile.NamedTemporaryFile(mode='w', suffix='.zsh', delete=False) as f:
            f.write(config)
            f.flush()

            validator = ConfigValidator(f.name)
            fixed, had_issues = validator.validate_and_fix()

            Path(f.name).unlink()

        self.assertFalse(had_issues)


def main():
    """Run tests."""
    unittest.main()


if __name__ == '__main__':
    main()
