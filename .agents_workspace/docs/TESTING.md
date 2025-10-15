# Testing

```bash
./test_zsh_plugins.sh  # All tests
./test_setup_repos.sh  # Setup script only
```

## Critical Bug Fixed

Tests caught a production bug: **macOS path canonicalization**.

On macOS, `/var` → `/private/var` (symlink). Git returns canonical paths, but string comparisons used symlink paths, breaking `list_worktrees`, `remove_worktree`, and `switch_worktree` on macOS.

**Fix**: Resolve to canonical paths before comparison (git-worktree-helper.zsh:323-687):
```zsh
canonical_path=$(cd "$WORKTREES_PATH" && pwd -P)
if [[ $path == $canonical_path* ]] || [[ $path == $WORKTREES_PATH* ]]; then
```

## Architecture

To make complex commands testable without launching IDEs or modifying production repos:
- **ci-helper.zsh:406-524** - Extracted `detect_ide_info()` (pure logic) and `launch_ide()` (side effects)
- **test_zsh_plugins.sh** - Uses real git in temp dirs for integration tests
