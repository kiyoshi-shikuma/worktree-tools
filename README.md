# Worktree Tools

Shell scripts and Oh My Zsh plugins for managing git worktrees and CI workflows across multiple repositories.

## Why Worktrees?

Git worktrees let you work on multiple branches simultaneously without constant switching or maintaining multiple clones. Instead of:
- Stashing changes to switch branches
- Maintaining separate repo clones
- Losing IDE state when switching

You get:
- Multiple branches checked out at once in separate directories
- Each worktree maintains its own working directory and IDE state
- Instant switching between branches using `cd` or directory bookmarks
- Shared git history (one `.git` directory for all worktrees)

## What This Repo Provides

- **Setup script** to convert existing repos or clone new ones into bare repo + worktree structure
- **Zsh commands** for creating, switching, listing, and removing worktrees
- **Template system** to copy config files automatically to new worktrees
- **CI shortcuts** (build/test/lint) that work across different repo types
- **Smart detection** of which repo you're in

## Quick Start

### 1. Setup Repositories

```bash
# Navigate to where you want your dev directory
cd ~/dev

# Clone this repo
git clone <this-repo-url> worktree-tools

# Setup your repositories (from existing local repos or remote URLs)
./worktree-tools/scripts/setup_repos.sh --repos "git@github.com:org/android.git,git@github.com:org/ios.git"

# Or from existing local repos:
./worktree-tools/scripts/setup_repos.sh --repos "/path/to/existing/android,/path/to/existing/ios"
```

This creates:
```
~/dev/
├── .repos/              # Bare repositories (shared git history)
├── worktrees/           # Your working directories
├── worktree_templates/  # Optional template files
└── worktree-tools/      # This repo (cloned here)
```

### 2. Install Plugins

```bash
cd worktree-tools
make install
# Follow prompts to edit config, then restart terminal
```

**Note**: The install script creates symlinks from `~/.oh-my-zsh/custom/` to the scripts in this repo, so updating is simple:
```bash
cd ~/dev/worktree-tools
git pull  # Updates take effect immediately (or after restarting terminal)
```

### 3. Configure

Edit `~/.config/worktree-tools/config.zsh`:

```zsh
GIT_USERNAME="your-username"
BRANCH_PREFIX="your-username"  # Creates branches like: your-username/feature-name

# Add your repository shortcuts
REPO_MAPPINGS[acmd]="Company-Android"
REPO_MAPPINGS[icmd]="Company-iOS"

# Optional: Enable CI commands (see CI Commands section)
# REPO_CONFIGS[acmd]="./gradlew assembleDebug|./gradlew testDebug|./gradlew lintDebug"

# Optional: Enable IDE command (see IDE Command section)
# REPO_IDE_CONFIGS[acmd]="android-studio||"
# REPO_IDE_CONFIGS[icmd]="xcode-workspace|Company-iOS.xcworkspace|"
```

### 4. Create Worktrees

```bash
# Create 2-3 long-lived worktrees for whatever work you want
wt-add acmd develop     # Tracking develop branch
wt-add acmd working     # Your main development work
wt-add acmd llmagent    # LLM agent work, PR reviews, experiments, etc.

wt-add icmd develop
wt-add icmd working
```

**Important**: The same branch cannot be checked out in multiple worktrees simultaneously. This can be a minor inconvenience with tools like Graphite that auto-prune merged branches, but you can just switch off the branch and delete/prune it later.

## Recommended Workflow

### Long-Lived Worktrees

Keep 2-3 long-lived worktrees per repository for different types of work. Common examples:
- **`develop`** - Tracking the develop branch, pulling latest changes
- **`working`** - Your primary development branch
- **`llmagent`** - LLM agent work, experiments, quick changes
- **`prreview`** - Reviewing PRs or addressing comments for your own

These are just examples - use whatever workflow fits your needs!

### Fast Switching with Bookmarks

For fastest navigation, use directory bookmarks:
- **Zsh users**: [bashmarks](https://github.com/huyng/bashmarks) works with zsh, or use [zshmarks](https://github.com/jocelynmallon/zshmarks) (a zsh-native port)
- **Bash users**: [bashmarks](https://github.com/huyng/bashmarks)

**Installing bashmarks for zsh:**
```bash
# Clone and install
git clone https://github.com/huyng/bashmarks.git
cd bashmarks
make install

# Add to ~/.zshrc (instead of ~/.bashrc)
echo 'source ~/.local/bin/bashmarks.sh' >> ~/.zshrc
source ~/.zshrc
```

**Using bashmarks (default commands):**
```bash
# Bookmark your worktrees once
cd ~/dev/worktrees/Company-Android-working
s acmd          # Save bookmark

cd ~/dev/worktrees/Company-iOS-working
s icmd

# Jump instantly from anywhere
g acmd          # Go to bookmark
l               # List all bookmarks
d acmd          # Delete bookmark (if needed)
```

Default commands: `s` (save), `g` (go), `l` (list), `d` (delete), `p` (print path). You can customize these by editing `~/.local/bin/bashmarks.sh`.

**Note**: If using zshmarks instead, see [their README](https://github.com/jocelynmallon/zshmarks#commands) for aliases to get similar brevity (`bookmark`, `jump`, `showmarks`, `deletemark` by default).

**Alternative**: Use `wt-switch` for fuzzy search:
```bash
wt-switch acmd work     # Switches to Company-Android-working
wt-switch icmd dev      # Switches to Company-iOS-develop
```

### Typical Development Cycle: Parallel Work Across Worktrees

One of the most powerful aspects of worktrees is working on multiple things simultaneously:

```bash
# Terminal 1: Launch Claude agent on a refactoring task
g llmagent
git checkout -b your-username/refactor-auth
# Launch Claude Code agent to refactor authentication
# Let it run autonomously...

# Terminal 2: Launch another Claude agent on bug fixes
g prreview
git checkout -b your-username/fix-login-bug
# Launch Claude Code agent to fix bug
# Let it run autonomously...

# Terminal 3: Work on a feature yourself
g working
git checkout -b your-username/new-payment-flow
ide           # Open IDE for this worktree
vgit          # Open Sourcetree for this worktree (see Tools section below)
# Work in IDE on new feature while agents work in other worktrees
```

All three branches are checked out simultaneously in different directories. You can:
- Monitor agent progress in terminals 1 & 2
- Work manually in your IDE in terminal 3
- Quickly jump between them with `g <bookmark>`
- Each worktree has its own git state, IDE state, and doesn't interfere with others

### Recommended Tools

**iTerm2 with Global Hotkey**: Set up [iTerm2](https://iterm2.com/) with a global hotkey (⌘`) to show/hide terminal instantly:
- Press hotkey → terminal appears
- `g working` → jump to working worktree
- `ide` → opens IDE for that worktree
- Press hotkey → back to IDE
- Ultra-fast context switching without mouse

**Git Visualizer**: Install [Sourcetree](https://www.sourcetreeapp.com/) and enable command-line tools (Sourcetree → Install Command Line Tools):
```bash
# Add to ~/.zshrc
alias vgit='stree .'

# Then from any worktree:
cd ~/dev/worktrees/Company-Android-working
vgit    # Opens Sourcetree for THIS specific worktree
```

**IDE Command**: Use the `ide` command to open the correct IDE for each worktree:
```bash
g working
ide     # Opens Android Studio / Xcode / VS Code for this worktree
```

## Worktree Commands

### Basic Commands

```bash
wt-add [repo] <branch-name>       # Create new worktree
wt-list [repo]                     # List all worktrees for repo
wt-switch [repo] <search-term>     # Switch to worktree (fuzzy match)
wt-rm [repo] <worktree-name>       # Remove worktree
```

**Examples:**
```bash
wt-add acmd feature-login          # Creates: Company-Android-feature-login
wt-list acmd                       # Lists all Android worktrees
wt-switch acmd login               # Switches to *-feature-login
wt-rm acmd feature-login           # Removes the worktree
```

**Note**: `[repo]` is optional if you're inside a worktree - it auto-detects which repo you're in.

### Template System

Templates let you copy files automatically to new worktrees (useful for IDE configs, local settings, etc.):

```bash
wt-template-save [repo]            # Save current files as template
wt-template-load [repo]            # Load template files to current worktree
```

**How it works:**
1. **Start by putting files in `worktree_templates/Your-Repo-Name/`** (e.g., `.idea/`, `local.properties`)
2. New worktrees automatically copy these template files
3. Use `wt-template-load` to update existing worktrees with latest templates
4. Use `wt-template-save` to update templates from current worktree - **NOTE:** This only overwrites/updates files that already exist in the template folder, so always start by manually adding files to the template folder first

## CI Commands

Run build/test/lint commands without remembering repo-specific syntax:

```bash
ci              # Run build + test + lint
test            # Run tests only
lint            # Run linting only
ci_modules      # Select a subset of modules for build + test (Gradle/Android only)
lint_modules    # Select a subset of modules for lint (Gradle/Android only)
ide             # Open appropriate IDE
```

**Note**: `ci_modules` and `lint_modules` only work for Gradle-based projects (Android). For other platforms, they fall back to running the full `ci` or `lint` commands.

### Enabling CI Commands

Add to `~/.config/worktree-tools/config.zsh`:

```zsh
# Format: "build_cmd|test_cmd|lint_cmd"
REPO_CONFIGS[acmd]="./gradlew assembleDebug|./gradlew testDebug|./gradlew lintDebug"
REPO_CONFIGS[icmd]="bundle exec fastlane build|bundle exec fastlane test|swiftlint --strict"

# Optional: For modular repos (enables ci_modules/lint_modules)
# Currently only supported for Gradle/Android projects
REPO_MODULES[acmd]="app-core app-auth app-profile"
```

### IDE Command

The `ide` command opens the appropriate IDE for your repository. Configure it in `~/.config/worktree-tools/config.zsh`:

```zsh
# Format: "ide_type|workspace_path|fallback_command"
# IDE types: android-studio, xcode-workspace, xcode-project, xcode-package, vscode

# Android Studio (auto-detects project)
REPO_IDE_CONFIGS[acmd]="android-studio||"

# Xcode with workspace
REPO_IDE_CONFIGS[icmd]="xcode-workspace|Company-iOS.xcworkspace|"

# Xcode with Swift Package
REPO_IDE_CONFIGS[ilib]="xcode-package|.swiftpm/xcode/package.xcworkspace|swift package generate-xcodeproj"

# VS Code
REPO_IDE_CONFIGS[web]="vscode||"
```

**Note**: You must specify the IDE type and workspace/project path (if applicable) - auto-detection is limited to detecting project structure, not IDE preferences.

## Config Migrations

If you have an old config format, migrate it to the latest version:

```bash
./scripts/migrate_config.sh ~/.config/worktree-tools/config.zsh
```

This adds version tracking and updates config keys to use shorthand format. A backup is created automatically.

## Setup Script Options

```bash
# Don't create initial worktrees (you'll add them manually)
./scripts/setup_repos.sh --repos "..." --no-initial-worktrees

# Use custom default branch
./scripts/setup_repos.sh --repos "..." --default-branch develop

# Per-repo branches (uses last colon as separator)
./scripts/setup_repos.sh --repos "git@github.com:org/repo1.git:main,repo2:develop"

# See all options
./scripts/setup_repos.sh --help
```

## Troubleshooting

### Plugin Not Loading
```bash
# Check installation (should see symlinks to your worktree-tools repo)
ls -la ~/.oh-my-zsh/custom/*helper.zsh
cat ~/.zshrc | grep worktree-tools

# Verify symlinks point to correct location
readlink ~/.oh-my-zsh/custom/git-worktree-helper.zsh
readlink ~/.oh-my-zsh/custom/ci-helper.zsh

# Reinstall if needed
cd worktree-tools
make uninstall
make install
exec zsh
```

### Worktree Issues
```bash
# List all worktrees (including broken ones)
git -C .repos/Repo-Name.git worktree list

# Remove stale worktree references
git -C .repos/Repo-Name.git worktree prune
```

### Commands Not Found
Make sure config is loaded: `source ~/.config/worktree-tools/config.zsh`

## Appendix: Why Bare Repos?

This tool uses **bare repositories** (`.repos/`) as the source of truth. Here's why this approach is better than alternatives:

### Bare Repo Approach (This Tool)
```
~/dev/
├── .repos/MyRepo.git          # Git storage (bare)
└── worktrees/
    ├── MyRepo-develop
    ├── MyRepo-working
    └── MyRepo-llmagent
```

**Benefits:**
- Clear separation: `.repos/` = git storage, `worktrees/` = working directories
- No confusion about which directory is "main"
- All worktrees are equal peers
- No local branches in `.repos/` to conflict with worktree branches
- Clean, organized structure

### Alternative 1: Sibling Worktrees
```
~/dev/
├── MyRepo/              # "Main" checkout (also a worktree)
├── MyRepo-working/      # Additional worktree
└── MyRepo-llmagent/     # Additional worktree
```

**Problems:**
- `MyRepo/` has a `.git` directory that can have local branches conflicting with other worktrees
- Unclear which directory is the "source of truth"
- One worktree appears special when they're all equal
- No clear place for git storage vs working directories

### Alternative 2: Worktrees Inside Repo
```
~/dev/MyRepo/
├── .git/
├── src/
├── worktrees/           # Worktrees nested inside main repo
│   ├── feature-a/
│   └── feature-b/
└── package.json
```

**Problems:**
- Worktrees mixed with your actual code
- Must add `worktrees/` to `.gitignore`
- IDE/build tools may index or process worktree files
- Clutters your project structure
- Confusing directory layout

### Why Bare Repos Win

The bare repo approach provides these benefits:

1. **No local branches** - Bare repos only track remotes, avoiding conflicts
2. **Shared git history** - One `.git` directory serves all worktrees (saves disk space)
3. **Cleaner worktree management** - Git tracks which worktrees exist and prevents conflicts
4. **Clear organization** - Storage vs working directories are separate
5. **Multi-repo friendly** - All bare repos in one place, all worktrees in another

Your worktrees in `worktrees/` are the "normal" working directories where you actually work. The bare repo is just plumbing.

## Contributing

This is an ongoing project. Found a bug or want a feature?

- **Issues**: File at `[https://github.com/kiyoshi-shikuma/worktree-tools/issues]`

Contributions welcome!

### Updating

Since the Oh My Zsh plugins are symlinked to this repo (not copied), updates are automatic:

```bash
cd ~/dev/worktree-tools  # or wherever you cloned this repo
git pull
exec zsh  # Reload shell to pick up changes
```

## Uninstallation

```bash
make uninstall  # Removes plugins, backs up config to config.zsh.old
```

Your repositories and worktrees remain untouched - only the zsh plugins are removed.
