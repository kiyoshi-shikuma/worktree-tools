# Worktree Tools

A set of shell scripts and Oh My Zsh plugins for managing git worktrees and CI workflows across multiple repositories.

## Features

- **🌳 Git Worktree Management**: Create, switch, list, and remove worktrees with simple commands
- **🔧 Repository Setup**: Bootstrap bare repositories from local or remote sources
- **🚀 Worktree aware commands**: Run build, test, and lint commands across different repositories
- **📋 Template System**: Automatically copy template files to new worktrees
- **🔗 Dependency Linking**: Create symlinks between related repositories
- **⚡ Smart Detection**: Auto-detect repositories from current directory

## Quick Start

### 1. Clone and Setup Repositories

First, navigate to where you want your worktree root directory (e.g., `~/dev`), then clone this repository and set up your bare repositories:

```bash
# Navigate to your desired worktree root
cd ~/dev  # or wherever you want your worktree structure

# Clone the worktree tools
git clone <this-repo-url> worktree-tools

# Setup repositories from the worktree root - choose one approach:

# Option A: Remote repositories
./worktree-tools/setup_repos.sh --repos "git@github.com:your-org/android.git,git@github.com:your-org/ios.git"

# Option B: Local repositories
./worktree-tools/setup_repos.sh --repos "/path/to/existing/android-repo,/path/to/existing/ios-repo"

# Option C: Mixed with custom default branches (options A and B will check for develop, main, and master)
./worktree-tools/setup_repos.sh --repos "git@github.com:your-org/android.git:main2,/path/to/ios-repo:main3" --default-branch main4
```

### 2. Install Oh My Zsh Plugins

Install the worktree management and CI helper plugins:

```bash
# Install plugins and create config (from the worktree-tools directory)
cd worktree-tools
make install

# Follow the prompts to:
# 1. Edit ~/.config/worktree-tools/config.zsh
# 2. Restart your terminal or run: exec zsh
```

### 3. Customize Configuration

Edit `~/.config/worktree-tools/config.zsh` to match your setup:

```zsh
# Your git username and branch prefix
GIT_USERNAME="your-username"
BRANCH_PREFIX="your-username"

# Repository shorthand mappings
REPO_MAPPINGS[android]="YourCompany-Android"
REPO_MAPPINGS[ios]="YourCompany-iOS"

# CI commands for each repository
REPO_CONFIGS[YourCompany-Android]="./gradlew assembleDebug|./gradlew testDebugUnitTest|./gradlew lintDebug"
REPO_CONFIGS[YourCompany-iOS]="bundle exec fastlane build|bundle exec fastlane unit_tests|swiftlint --strict"
```

### 4. Start Using Worktrees

```bash
# Create new worktrees
wt-add android working
wt-add ios prs

# List worktrees
wt-list android
wt-list ios

# Switch between worktrees
wt-switch android working
wt-switch ios prs

# Run CI commands
cd worktrees/YourCompany-Android-working
ci          # Run full CI pipeline
test        # Run tests only
lint        # Run linting only

# Clean up when done (or keep long running)
wt-rm android feature-login
```

## Repository Setup Details

The `setup_repos.sh` script creates a specific directory structure optimized for worktree workflows:

```
your-project/
├── .repos/                    # Bare git repositories
│   ├── YourApp-Android.git
│   └── YourApp-iOS.git
├── worktrees/                 # Individual worktrees per branch
│   ├── YourApp-Android-main
│   ├── YourApp-Android-feature-x
│   ├── YourApp-iOS-main
│   └── YourApp-iOS-feature-y
└── worktree_templates/        # Template files for new worktrees (or loading into existing)
    ├── YourApp-Android/
    └── YourApp-iOS/
```

### Repository Specification Options

The `--repos` parameter accepts various formats:

```bash
# Remote Git URLs
--repos "git@github.com:org/repo.git,https://github.com/org/repo2.git"

# Local paths (absolute or relative)
--repos "/path/to/existing/repo1,../relative/repo2"

# Mixed with custom branches (uses last colon as separator)
--repos "git@github.com:org/repo.git:develop,/local/repo:main"

# SSH URLs work correctly (scp-style)
--repos "user@server:path/repo.git,git@github.com:org/repo.git:feature-branch"
```

### Branch Resolution

The script resolves the base branch in this order:
1. Explicit per-repo override (`repo:branch` syntax)
2. `--default-branch` parameter value
3. Remote HEAD (`origin/HEAD`)
4. Common branches: `develop`, `main`, `master`

### Additional Options

```bash
# Don't create initial worktrees
./setup_repos.sh --repos "..." --no-initial-worktrees

# Use different default branch
./setup_repos.sh --repos "..." --default-branch develop

# See all options
./setup_repos.sh --help
```

## Available Commands

Once installed, you'll have access to these commands:

### Worktree Management
```bash
wt-add [<repo>] <branch-name>     # Create new worktree
wt-list [<repo>]                  # List worktrees
wt-switch [<repo>] <search>       # Switch to worktree matching search
wt-rm [<repo>] <worktree-name>    # Remove worktree
wt-template-save [<repo>]         # Save current files as template (files that match whats currently in the corresponding template folder)
wt-template-load [<repo>]         # Load template files to worktree (all files that re in the corresponding template folder)
```

### Dependency Management
```bash
deps-link <repo>                  # Create symlink to dependency worktree (should be to an `llmdeps` worktree)
deps-rm                           # Remove all dependency symlinks
```

### CI/Build Commands
```bash
ci                              # Run full CI pipeline
test                            # Run tests only
lint                            # Run linting only
ci_modules                      # Run CI for configured modules
lint_modules                    # Run lint for configured modules
ide                             # Open appropriate IDE
```

## Configuration

### Repository Mappings
Define shorthand names for your repositories:

```zsh
REPO_MAPPINGS[web]="MyCompany-WebApp"
REPO_MAPPINGS[api]="MyCompany-API" 
REPO_MAPPINGS[android]="MyCompany-Android"
REPO_MAPPINGS[ios]="MyCompany-iOS"
```

### CI Commands
Configure build, test, and lint commands for each repository:

```zsh
# Format: "build_cmd|test_cmd|lint_cmd"
REPO_CONFIGS[MyCompany-WebApp]="npm run build|npm run test|npm run lint"
REPO_CONFIGS[MyCompany-API]="go build|go test ./...|golangci-lint run"
REPO_CONFIGS[MyCompany-Android]="./gradlew assembleDebug|./gradlew testDebugUnitTest|./gradlew lintDebug"
REPO_CONFIGS[MyCompany-iOS]="bundle exec fastlane build|bundle exec fastlane unit_tests|swiftlint --strict"
```

### Module Support (Optional)
For repositories with modular builds (like Android with Gradle modules):

```zsh
REPO_MODULES[MyCompany-Android]="core-module feature-module"
REPO_MODULES[MyCompany-Library]="shared-utils common-models"
```

## Templates and Dependencies

### Template System
Templates allow you to automatically copy configuration files to new worktrees:

1. Create template directories: `worktree_templates/YourRepo-Name/`
2. Add files you want copied to every new worktree
3. Templates are automatically applied when creating worktrees

### Dependency Linking
Link related repositories together during development:

```bash
# From your main app worktree, link to a library
deps-link library

# This creates: .dev_workspace/symdeps/YourLibrary -> /path/to/library/worktree
# Most build systems can follow symlinks for local development
```

## Examples

### Multi-Repository Development Workflow

```bash
# Navigate to desired worktree root
cd ~/dev

# Setup repositories
./worktree-tools/setup_repos.sh --repos "git@github.com:company/android.git,git@github.com:company/ios.git,git@github.com:company/shared-lib.git"

# Install tools
cd worktree-tools
make install
# Edit ~/.config/worktree-tools/config.zsh
exec zsh

# Start feature development
wt-add android feature-auth
wt-add ios feature-auth  
wt-add shared auth-utils

# Link dependencies
cd worktrees/Company-Android-feature-auth
deps-link shared

cd ../Company-iOS-feature-auth  
deps-link shared

# Development workflow
cd ../Company-Android-feature-auth
ci          # Build, test, lint
ide         # Open Android Studio

cd ../Company-iOS-feature-auth
test        # Run tests only
ide         # Open Xcode
```

### Working with Existing Local Repositories

```bash
# Navigate to desired worktree root
cd ~/dev

# You have existing repos at /src/mobile-android and /src/mobile-ios
./worktree-tools/setup_repos.sh --repos "/src/mobile-android,/src/mobile-ios"

# This creates bare clones while preserving your original repos
# The bare repos will use the same remote URLs as your originals
```

## Troubleshooting

### Installation Issues
```bash
# Check installation status
make help

# Reinstall (removes existing installation first)
make uninstall
make install

# Manual cleanup if needed
rm -rf ~/.config/worktree-tools
rm -f ~/.oh-my-zsh/custom/git-worktree-helper.zsh
rm -f ~/.oh-my-zsh/custom/ci-helper.zsh
```

### Worktree Issues
```bash
# List all worktrees (including ones outside our structure)
git -C .repos/YourRepo.git worktree list

# Remove broken worktree references
git -C .repos/YourRepo.git worktree prune

# Fix detached worktrees
cd problematic-worktree
git checkout -b your-username/branch-name
```

### Branch Prefix Issues
- Branch names cannot contain `/` characters
- The `BRANCH_PREFIX` is automatically prepended (e.g., `kiyoshi/feature-name`)
- Remote branches are tracked automatically when they exist

## Uninstallation

```bash
# Uninstall (backs up your config to config.zsh.old)
make uninstall

# Your worktrees and repositories remain untouched
# Only the oh-my-zsh plugins and config are removed
```

## License

See LICENSE file for details.
