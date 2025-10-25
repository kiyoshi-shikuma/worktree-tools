# Agent Documentation

This file provides guidance for LLMs/agents working on this repository.

## Repository Overview

This is a worktree tools repository containing shell scripts for managing git worktrees and CI workflows. The main components are:

- **setup_repos.sh**: Bootstrap script for setting up bare repositories and initial worktrees
- **git-worktree-helper.zsh**: Oh-my-zsh plugin for managing git worktrees across multiple repositories
- **ci-helper.zsh**: Oh-my-zsh plugin for running CI/lint commands in multi-repository workflows

## Key Commands

### Repository Setup
```bash
./setup_repos.sh --repos "repo1,repo2" [--default-branch <branch>] [--no-initial-worktrees]
```

### Git Worktree Management (via zsh aliases)
```bash
wt-add [<repo>] <branch-name>     # Create new worktree
wt-list [<repo>]                  # List worktrees
wt-switch [<repo>] <search>       # Switch to worktree
wt-rm [<repo>] <worktree-name>    # Remove worktree
wt-template-save [<repo>]         # Save current template files
wt-template-load [<repo>]         # Load template files to worktree
deps-link <repo>                  # Create dependency symlinks
deps-rm                           # Remove all dependency symlinks
```

### CI/Build Commands (via zsh aliases)
```bash
ci                               # Run full CI pipeline
test                            # Run tests only
lint                            # Run linting only
ci_modules                      # Run CI for configured modules
lint_modules                    # Run lint for configured modules only
ide                             # Open appropriate IDE for current repo
```

## Architecture

### Directory Structure
The tools expect this structure:
```
.repos/          # Bare git repositories (no local branches)
worktrees/       # Individual worktrees per branch
worktree_templates/  # Template files for new worktrees
```

### Configuration Files
- **config.zsh**: Main configuration file loaded by both plugins (placed in `~/.config/worktree-tools/`)
- **config.zsh.example**: Template showing configuration format for new users
- **git-worktree-helper.zsh**: Configure `REPO_MAPPINGS` for repository shorthands and paths
- **ci-helper.zsh**: Configure `REPO_CONFIGS` for build/test/lint commands and `REPO_MODULES` for modular builds

### Worktree Workflow
1. Bare repositories contain only remote-tracking refs (no local branches)
2. Local branches are created only when adding worktrees
3. Branch names are automatically prefixed (configurable via `BRANCH_PREFIX`)
4. Template files can be automatically copied to new worktrees

## Important Notes

- The setup script creates bare repos with NO local branches to avoid conflicts
- Both zsh plugins use lazy loading for performance
- Repository detection works via git remote URL or directory path matching
- Templates and dependency symlinks support complex multi-repo development workflows
- Branch names are automatically prefixed with user's configured prefix (e.g., `username/feature-name`)
- Commands support both explicit repository specification and auto-detection from current directory
- Configuration is externalized to `~/.config/worktree-tools/config.zsh` for easy customization

## Testing

See `.agents_workspace/docs/TESTING.md` for test strategy, critical bugs fixed, and architecture for testability.
