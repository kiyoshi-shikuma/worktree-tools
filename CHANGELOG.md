# Changelog

## [0.3.0] - 2025-01-23

### Added
- Config migration system with `migrate_config.sh` and version tracking
- Comprehensive test suites (`test_zsh_plugins.sh`, `test_setup_repos.sh`, `test_migrations.sh`)
- Migration to convert old config format to shorthand keys
- Agent documentation in `.agents_workspace/docs/`

### Changed
- README rewritten for clarity with parallel workflow examples and tool recommendations
- CLAUDE.md converted to symlink pointing to AGENTS.md

### Removed
- Dependency linking features (`deps-link`, `deps-rm`) - not widely useful

### Fixed
- macOS path canonicalization bug in worktree operations (symlink `/var` vs `/private/var`)
- Multiple bugs in `setup_repos.sh` (see bugfix commits in version history)
