#!/usr/bin/env python3
"""Tests for normalize_config.py"""

import unittest
from normalize_config import ConfigNormalizer


class TestConfigNormalizer(unittest.TestCase):
    """Test config normalization."""

    def setUp(self):
        """Set up test fixtures."""
        self.example_config = '''#!/usr/bin/env zsh
# Worktree Tools Configuration
# Copy to: ~/.config/worktree-tools/config.zsh

# Config version (for migrations)
CONFIG_VERSION=1

# =============================================================================
# REQUIRED: Update these for your setup
# =============================================================================

GIT_USERNAME="${USER}"

# Branch prefix (set to "" for no prefix)
# "john" creates: john/my-feature
# "" creates: my-feature
BRANCH_PREFIX="${USER}"

# Where you ran setup_repos.sh (contains .repos/ and worktrees/)
# Examples: "$HOME/work/mobile", "$HOME/dev", "$HOME/projects"
BASE_DEV_PATH="$HOME/dev"

# =============================================================================
# Repository shortcuts
# =============================================================================

[[ -z ${(t)REPO_MAPPINGS} ]] && declare -gA REPO_MAPPINGS

# Add your repos here:
# REPO_MAPPINGS[shorthand]="Full-Repo-Name"
#
# Examples:
# REPO_MAPPINGS[acmd]="Company-Android"
# REPO_MAPPINGS[alib]="Company-Android-Library"
# REPO_MAPPINGS[icmd]="Company-iOS"
# REPO_MAPPINGS[ilib]="Company-iOS-Library"

# =============================================================================
# Optional: IDE configuration (uncomment to enable 'ide' command)
# =============================================================================

# Opens the configured IDE when you run 'ide' from within a repo
# Format: "ide_type|workspace_path|fallback_command"
#
# NOTE: You can use either shorthand OR full repo name as keys.
#       Shorthand is recommended, but both work for backward compatibility.

# REPO_IDE_CONFIGS[acmd]="android-studio||"
# REPO_IDE_CONFIGS[alib]="android-studio||"
# REPO_IDE_CONFIGS[icmd]="xcode-workspace|Company-iOS.xcworkspace|"
# REPO_IDE_CONFIGS[ilib]="xcode-package|.swiftpm/xcode/package.xcworkspace|swift package generate-xcodeproj"

# =============================================================================
# Optional: CI commands (uncomment to enable ci/test/lint shortcuts)
# =============================================================================

# Enables running 'ci', 'test', or 'lint' from within a repo
# Format: "build_cmd|test_cmd|lint_cmd"
#
# NOTE: You can use either shorthand OR full repo name as keys.
#       Shorthand is recommended, but both work for backward compatibility.

# Android example:
# REPO_CONFIGS[acmd]="./gradlew --quiet assembleDebug|./gradlew --quiet testDebugUnitTest|./gradlew --quiet lintDebug detekt"

# iOS example:
# REPO_CONFIGS[icmd]="bundle exec fastlane build|bundle exec fastlane unit_tests|swiftlint --strict"

# Web example:
# REPO_CONFIGS[web]="npm run build|npm test|npm run lint"

# =============================================================================
# Optional: Modular builds (uncomment to enable ci_modules/lint_modules)
# =============================================================================

# For monorepos with multiple modules - lets you select which ones to build/lint
# Format: space-separated list of modules
#
# NOTE: You can use either shorthand OR full repo name as keys.
#       Shorthand is recommended, but both work for backward compatibility.

# Android modules:
# REPO_MODULES[acmd]="app-core app-feature-auth app-feature-profile"

# iOS modules:
# REPO_MODULES[icmd]="CoreModule AuthModule ProfileModule"

# Web packages:
# REPO_MODULES[web]="packages/ui packages/api packages/utils"

# =============================================================================
# Auto-computed paths (don't change unless you have custom structure)
# =============================================================================

BARE_REPOS_PATH="$BASE_DEV_PATH/.repos"
WORKTREES_PATH="$BASE_DEV_PATH/worktrees"
WORKTREE_TEMPLATES_PATH="$BASE_DEV_PATH/worktree_templates"
'''

    def test_extract_simple_variables(self):
        """Test extracting simple variables."""
        user_config = '''#!/usr/bin/env zsh
CONFIG_VERSION=1
GIT_USERNAME=testuser
BRANCH_PREFIX=testuser
BASE_DEV_PATH=/home/test/dev
'''
        normalizer = ConfigNormalizer(user_config, self.example_config)

        self.assertEqual(normalizer.user_values['simple']['CONFIG_VERSION'], '1')
        self.assertEqual(normalizer.user_values['simple']['GIT_USERNAME'], 'testuser')
        self.assertEqual(normalizer.user_values['simple']['BRANCH_PREFIX'], 'testuser')
        self.assertEqual(normalizer.user_values['simple']['BASE_DEV_PATH'], '/home/test/dev')

    def test_extract_repo_mappings(self):
        """Test extracting REPO_MAPPINGS."""
        user_config = '''
REPO_MAPPINGS[acmd]="MyCompany-Android"
REPO_MAPPINGS[icmd]="MyCompany-iOS"
'''
        normalizer = ConfigNormalizer(user_config, self.example_config)

        self.assertEqual(len(normalizer.user_values['mappings']), 2)
        self.assertIn(('acmd', 'MyCompany-Android'), normalizer.user_values['mappings'])
        self.assertIn(('icmd', 'MyCompany-iOS'), normalizer.user_values['mappings'])

    def test_extract_ide_configs(self):
        """Test extracting REPO_IDE_CONFIGS."""
        user_config = '''
REPO_IDE_CONFIGS[acmd]="android-studio||"
REPO_IDE_CONFIGS[icmd]="xcode-workspace|MyApp.xcworkspace|"
'''
        normalizer = ConfigNormalizer(user_config, self.example_config)

        self.assertEqual(len(normalizer.user_values['ide_configs']), 2)
        self.assertIn(('acmd', 'android-studio||'), normalizer.user_values['ide_configs'])
        self.assertIn(('icmd', 'xcode-workspace|MyApp.xcworkspace|'), normalizer.user_values['ide_configs'])

    def test_extract_repo_configs(self):
        """Test extracting REPO_CONFIGS."""
        user_config = '''
REPO_CONFIGS[acmd]="./gradlew build|./gradlew test|./gradlew lint"
REPO_CONFIGS[web]="npm run build|npm test|npm run lint"
'''
        normalizer = ConfigNormalizer(user_config, self.example_config)

        self.assertEqual(len(normalizer.user_values['repo_configs']), 2)
        self.assertIn(('acmd', './gradlew build|./gradlew test|./gradlew lint'), normalizer.user_values['repo_configs'])
        self.assertIn(('web', 'npm run build|npm test|npm run lint'), normalizer.user_values['repo_configs'])

    def test_extract_repo_modules(self):
        """Test extracting REPO_MODULES."""
        user_config = '''
REPO_MODULES[acmd]="core auth profile"
REPO_MODULES[web]="packages/ui packages/api"
'''
        normalizer = ConfigNormalizer(user_config, self.example_config)

        self.assertEqual(len(normalizer.user_values['repo_modules']), 2)
        self.assertIn(('acmd', 'core auth profile'), normalizer.user_values['repo_modules'])
        self.assertIn(('web', 'packages/ui packages/api'), normalizer.user_values['repo_modules'])

    def test_normalize_preserves_user_values(self):
        """Test that normalization preserves user values."""
        user_config = '''#!/usr/bin/env zsh
CONFIG_VERSION=1
GIT_USERNAME=testuser
BRANCH_PREFIX=testuser
BASE_DEV_PATH=/home/testuser/projects/mobile

[[ -z ${(t)REPO_MAPPINGS} ]] && declare -gA REPO_MAPPINGS
REPO_MAPPINGS[icmd]="MyOrg-iOS"
REPO_MAPPINGS[acmd]="MyOrg-Android"

REPO_IDE_CONFIGS[acmd]="android-studio||"

REPO_CONFIGS[acmd]="./gradlew assembleDebug|./gradlew test|./gradlew lint"

REPO_MODULES[acmd]="app-core app-auth"
'''
        normalizer = ConfigNormalizer(user_config, self.example_config)
        normalized = normalizer.normalize()

        # Check simple variables
        self.assertIn('GIT_USERNAME=testuser', normalized)
        self.assertIn('BRANCH_PREFIX=testuser', normalized)
        self.assertIn('BASE_DEV_PATH=/home/testuser/projects/mobile', normalized)

        # Check REPO_MAPPINGS
        self.assertIn('REPO_MAPPINGS[icmd]="MyOrg-iOS"', normalized)
        self.assertIn('REPO_MAPPINGS[acmd]="MyOrg-Android"', normalized)
        # Should NOT contain example mappings as uncommented lines
        uncommented_lines = [l for l in normalized.split('\n') if l.startswith('REPO_MAPPINGS[')]
        self.assertEqual(len(uncommented_lines), 2)  # Only user's 2 mappings
        for line in uncommented_lines:
            self.assertNotIn('Company-', line)

        # Check REPO_IDE_CONFIGS
        self.assertIn('REPO_IDE_CONFIGS[acmd]="android-studio||"', normalized)

        # Check REPO_CONFIGS
        self.assertIn('REPO_CONFIGS[acmd]="./gradlew assembleDebug|./gradlew test|./gradlew lint"', normalized)

        # Check REPO_MODULES
        self.assertIn('REPO_MODULES[acmd]="app-core app-auth"', normalized)

    def test_normalize_preserves_structure(self):
        """Test that normalization preserves comment structure."""
        user_config = '''#!/usr/bin/env zsh
CONFIG_VERSION=1
GIT_USERNAME=testuser
BRANCH_PREFIX=testuser
BASE_DEV_PATH=/home/test/dev

[[ -z ${(t)REPO_MAPPINGS} ]] && declare -gA REPO_MAPPINGS
REPO_MAPPINGS[web]="MyApp-Web"
'''
        normalizer = ConfigNormalizer(user_config, self.example_config)
        normalized = normalizer.normalize()

        # Check structure is preserved
        self.assertIn('# Worktree Tools Configuration', normalized)
        self.assertIn('# REQUIRED: Update these for your setup', normalized)
        self.assertIn('# Repository shortcuts', normalized)
        self.assertIn('# Optional: IDE configuration', normalized)
        self.assertIn('# Optional: CI commands', normalized)
        self.assertIn('# Optional: Modular builds', normalized)
        self.assertIn('# Auto-computed paths', normalized)

    def test_normalize_empty_arrays(self):
        """Test normalization with no array entries."""
        user_config = '''#!/usr/bin/env zsh
CONFIG_VERSION=1
GIT_USERNAME=testuser
BRANCH_PREFIX=testuser
BASE_DEV_PATH=/home/test/dev

[[ -z ${(t)REPO_MAPPINGS} ]] && declare -gA REPO_MAPPINGS
'''
        normalizer = ConfigNormalizer(user_config, self.example_config)
        normalized = normalizer.normalize()

        # Should have structure but no actual mappings
        self.assertIn('[[ -z ${(t)REPO_MAPPINGS}', normalized)
        # Should not have any uncommented REPO_MAPPINGS entries
        lines = [l for l in normalized.split('\n') if l.startswith('REPO_MAPPINGS[')]
        self.assertEqual(len(lines), 0)

    def test_convert_full_names_to_shorthand(self):
        """Test converting full repo names to shorthand in configs."""
        user_config = '''#!/usr/bin/env zsh
CONFIG_VERSION=1
GIT_USERNAME=testuser
BRANCH_PREFIX=testuser
BASE_DEV_PATH=/home/test/dev

[[ -z ${(t)REPO_MAPPINGS} ]] && declare -gA REPO_MAPPINGS
REPO_MAPPINGS[acmd]="Company-Android"
REPO_MAPPINGS[icmd]="Company-iOS"

# Old format: using full repo names as keys
REPO_CONFIGS[Company-Android]="./gradlew build|./gradlew test|./gradlew lint"
REPO_CONFIGS[Company-iOS]="bundle exec fastlane build|bundle exec fastlane test|swiftlint"

REPO_MODULES[Company-Android]="app-core app-auth"

REPO_IDE_CONFIGS[Company-Android]="android-studio||"
REPO_IDE_CONFIGS[Company-iOS]="xcode-workspace|Company-iOS.xcworkspace|"
'''
        normalizer = ConfigNormalizer(user_config, self.example_config)

        # Check extraction converts to shorthand
        self.assertEqual(len(normalizer.user_values['repo_configs']), 2)
        self.assertIn(('acmd', './gradlew build|./gradlew test|./gradlew lint'),
                      normalizer.user_values['repo_configs'])
        self.assertIn(('icmd', 'bundle exec fastlane build|bundle exec fastlane test|swiftlint'),
                      normalizer.user_values['repo_configs'])

        self.assertEqual(len(normalizer.user_values['repo_modules']), 1)
        self.assertIn(('acmd', 'app-core app-auth'), normalizer.user_values['repo_modules'])

        self.assertEqual(len(normalizer.user_values['ide_configs']), 2)
        self.assertIn(('acmd', 'android-studio||'), normalizer.user_values['ide_configs'])
        self.assertIn(('icmd', 'xcode-workspace|Company-iOS.xcworkspace|'),
                      normalizer.user_values['ide_configs'])

        # Check normalized output uses shorthand
        normalized = normalizer.normalize()

        # Should have shorthand keys in output
        self.assertIn('REPO_CONFIGS[acmd]="./gradlew build|./gradlew test|./gradlew lint"', normalized)
        self.assertIn('REPO_CONFIGS[icmd]="bundle exec fastlane build|bundle exec fastlane test|swiftlint"', normalized)
        self.assertIn('REPO_MODULES[acmd]="app-core app-auth"', normalized)
        self.assertIn('REPO_IDE_CONFIGS[acmd]="android-studio||"', normalized)
        self.assertIn('REPO_IDE_CONFIGS[icmd]="xcode-workspace|Company-iOS.xcworkspace|"', normalized)

        # Should NOT have full names as keys
        self.assertNotIn('REPO_CONFIGS[Company-Android]', normalized)
        self.assertNotIn('REPO_CONFIGS[Company-iOS]', normalized)
        self.assertNotIn('REPO_MODULES[Company-Android]', normalized)
        self.assertNotIn('REPO_IDE_CONFIGS[Company-Android]', normalized)
        self.assertNotIn('REPO_IDE_CONFIGS[Company-iOS]', normalized)

    def test_mixed_shorthand_and_full_names(self):
        """Test handling mix of shorthand and full names."""
        user_config = '''#!/usr/bin/env zsh
[[ -z ${(t)REPO_MAPPINGS} ]] && declare -gA REPO_MAPPINGS
REPO_MAPPINGS[acmd]="Company-Android"
REPO_MAPPINGS[web]="MyApp-Web"

# Mix: one uses full name, one uses shorthand
REPO_CONFIGS[Company-Android]="./gradlew build|./gradlew test|./gradlew lint"
REPO_CONFIGS[web]="npm run build|npm test|npm run lint"
'''
        normalizer = ConfigNormalizer(user_config, self.example_config)

        # Both should be converted/kept as shorthand
        self.assertIn(('acmd', './gradlew build|./gradlew test|./gradlew lint'),
                      normalizer.user_values['repo_configs'])
        self.assertIn(('web', 'npm run build|npm test|npm run lint'),
                      normalizer.user_values['repo_configs'])


def main():
    """Run tests."""
    unittest.main()


if __name__ == '__main__':
    main()
