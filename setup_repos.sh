#!/usr/bin/env bash
# setup_worktrees.sh
# One-shot bootstrap: bare repos (no local branches) + optional initial worktrees.

set -euo pipefail

DEFAULT_BRANCH="develop"
REPOS_CSV=""
CREATE_INITIAL_WT=1  # 1=yes, 0=no

usage() {
  cat <<EOF
Usage: $(basename "$0") --repos "<repo1,repo2,...>" [--default-branch <branch>] [--no-initial-worktrees]

<repo> can be:
  - Git URL (e.g., git@github.com:org/android.git)
  - Local path to existing git repo (relative or absolute, e.g., ../my-repo or /path/to/repo)
  - OR "<URL-or-path>:<branch>" to override the default branch for that repo.
    (The *last* colon is used as the separator, so scp-style SSH is safe.)

Branch resolution order (when no explicit override is given):
  1) Explicit per-repo override (repo:branch syntax)
  2) --default-branch value if specified
  3) Remote HEAD (origin/HEAD)
  4) Common branches in order: develop, main, master

Examples:
  $(basename "$0") --repos "git@github.com:org/android.git,git@github.com:org/ios.git"
  $(basename "$0") --repos "git@github.com:org/android.git:release/2.x,git@github.com:org/ios.git" --default-branch develop
  $(basename "$0") --repos "/src/ios-lib.git:main,../existing-repo:develop" --no-initial-worktrees

Creates in the current directory:
  ./.repos/<name>.git              (bare repos; no local branches)
  ./worktrees/<name>-<branch>      (initial worktrees; skipped if --no-initial-worktrees)
EOF
}

# ---- CLI parsing ----
while [[ $# -gt 0 ]]; do
  case "$1" in
    --repos) REPOS_CSV="${2:-}"; shift 2 ;;
    --default-branch|-b) DEFAULT_BRANCH="${2:-}"; shift 2 ;;
    --no-initial-worktrees) CREATE_INITIAL_WT=0; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; usage; exit 1 ;;
  esac
done

if [[ -z "$REPOS_CSV" ]]; then
  echo "Error: --repos is required" >&2
  usage
  exit 1
fi

ROOT="$PWD"
REPOS_DIR="$ROOT/.repos"
WTS_DIR="$ROOT/worktrees"
mkdir -p "$REPOS_DIR" "$WTS_DIR"

# ---- helpers ----

repo_basename() {
  local in="$1"
  in="${in%/}"
  local base="${in##*/}"
  base="${base##*:}"
  base="${base%.git}"
  echo "$base"
}

# Echoes "URL|BRANCH_OVERRIDE" (branch may be empty)
parse_repo_item() {
  local item="$1"
  local url="$item"
  local branch_override=""

  local colon_count
  colon_count=$(awk -F: '{print NF-1}' <<<"$item")

  if (( colon_count >= 1 )); then
    if [[ "$item" == *"://"* ]]; then
      # scheme URLs (https://, ssh://). Only treat a colon *after* scheme as override.
      local last="${item##*:}"
      local prefix="${item%:*}"
      if [[ "$prefix" == *"://"* ]]; then
        url="$prefix"
        branch_override="$last"
      fi
    elif [[ "$item" == *"@"* ]]; then
      # scp-style SSH (git@host:path). Need >=2 colons to have an override.
      if (( colon_count >= 2 )); then
        local last="${item##*:}"
        local prefix="${item%:*}"
        url="$prefix"
        branch_override="$last"
      fi
    else
      # local path or simple URL with :branch
      local last="${item##*:}"
      local prefix="${item%:*}"
      url="$prefix"
      branch_override="$last"
    fi
  fi

  echo "$url|$branch_override"
}

# Choose base branch:
# 1) explicit override (if exists)
# 2) global DEFAULT_BRANCH (if exists)
# 3) origin/HEAD
# 4) develop, main, then master
resolve_base_branch() {
  local bare="$1"
  local explicit="${2:-}"

  if [[ -n "$explicit" ]] && git -C "$bare" show-ref --verify --quiet "refs/remotes/origin/$explicit"; then
    echo "$explicit"; return 0
  fi
  if git -C "$bare" show-ref --verify --quiet "refs/remotes/origin/$DEFAULT_BRANCH"; then
    echo "$DEFAULT_BRANCH"; return 0
  fi
  if git -C "$bare" remote set-head origin -a >/dev/null 2>&1; then
    local headref
    headref="$(git -C "$bare" symbolic-ref -q refs/remotes/origin/HEAD || true)"
    if [[ -n "$headref" ]]; then
      echo "${headref##refs/remotes/origin/}"; return 0
    fi
  fi
  for fb in develop main master; do
    if git -C "$bare" show-ref --verify --quiet "refs/remotes/origin/$fb"; then
      echo "$fb"; return 0
    fi
  done
  echo "$DEFAULT_BRANCH"
}

# Initialize a bare repo that has *no* local branches; only remote-tracking refs
init_bare_repo_no_locals() {
  local bare="$1"
  local remote="$2"
  
  # Expand tilde in remote path if present
  remote="${remote/#\~/$HOME}"

  if [[ ! -d "$bare" ]]; then
    if [[ -d "$remote" ]]; then
      # Local path: clone from existing repo
      git clone --bare "$remote" "$bare"
      
      # Copy the original remote URL from the source repo
      local original_remote
      original_remote=$(git -C "$remote" remote get-url origin 2>/dev/null || true)
      if [[ -n "$original_remote" ]]; then
        git -C "$bare" remote set-url origin "$original_remote"
      fi
    else
      # Remote URL: initialize and add remote
      git init --bare "$bare"
      git -C "$bare" remote add origin "$remote"
    fi
  fi

  # For local repos, ensure we have the right remote config
  if [[ -d "$remote" ]]; then
    local original_remote
    original_remote=$(git -C "$remote" remote get-url origin 2>/dev/null || true)
    if [[ -n "$original_remote" ]]; then
      git -C "$bare" remote set-url origin "$original_remote" >/dev/null 2>&1 || true
    fi
  fi

  # Normalize refspec (avoid accidental locals)
  git -C "$bare" config --unset-all remote.origin.fetch >/dev/null 2>&1 || true
  git -C "$bare" config --add remote.origin.fetch '+refs/heads/*:refs/remotes/origin/*'
  git -C "$bare" config fetch.prune true

  # No local branches created here:
  git -C "$bare" fetch origin --prune --tags
}

# ---- per-repo QoL config helper ----
setup_repo_config() {
  local bare="$1"
  git -C "$bare" config push.default current >/dev/null 2>&1 || true
  git -C "$bare" config fetch.prune true >/dev/null 2>&1 || true
  # Pick your rebase preference:
  # git -C "$bare" config pull.rebase false >/dev/null 2>&1 || true
  # git -C "$bare" config pull.rebase true  >/dev/null 2>&1 || true
}

# ---- process repos ----
IFS=',' read -r -a REPO_ITEMS <<< "$REPOS_CSV"

echo "Workspace: $ROOT"
echo "Bare:      $REPOS_DIR"
echo "Worktrees: $WTS_DIR"
echo "Default:   $DEFAULT_BRANCH"
echo

for raw in "${REPO_ITEMS[@]}"; do
  item="$(echo "$raw" | xargs)"  # trim
  [[ -z "$item" ]] && continue

  parsed="$(parse_repo_item "$item")"
  REPO_URL="${parsed%%|*}"
  PER_REPO_BRANCH="${parsed##*|}"

  NAME="$(repo_basename "$REPO_URL")"
  BARE="$REPOS_DIR/$NAME.git"

  echo "=== $NAME"
  echo "Source: $REPO_URL"
  [[ -n "$PER_REPO_BRANCH" ]] && echo "Per-repo branch: $PER_REPO_BRANCH"

  init_bare_repo_no_locals "$BARE" "$REPO_URL"

  # Setup per-repo git configs
  setup_repo_config "$BARE"

  # Better UX for future worktrees
  git -C "$BARE" config worktree.guessRemote true

  BASE_BRANCH="$(resolve_base_branch "$BARE" "$PER_REPO_BRANCH")"
  echo "Base branch: $BASE_BRANCH"

  if (( CREATE_INITIAL_WT )); then
    SAFE_BRANCH="${BASE_BRANCH//\//-}"
    WT_DIR="$WTS_DIR/$NAME-$SAFE_BRANCH"
    if [[ -d "$WT_DIR" ]]; then
      echo "Worktree exists: $WT_DIR"
    else
      # Create worktree, using existing local branch if available
      if git -C "$BARE" show-ref --verify --quiet "refs/heads/$BASE_BRANCH"; then
        # Local branch exists, use it directly
        git -C "$BARE" worktree add "$WT_DIR" "$BASE_BRANCH"
      elif git -C "$BARE" show-ref --verify --quiet "refs/remotes/origin/$BASE_BRANCH"; then
        # Remote branch exists, create tracking local branch
        git -C "$BARE" worktree add --track -b "$BASE_BRANCH" "$WT_DIR" "origin/$BASE_BRANCH"
      else
        # fall back to origin/HEAD if base not present
        git -C "$BARE" remote set-head origin -a >/dev/null 2>&1 || true
        HEAD_BRANCH="$(git -C "$BARE" symbolic-ref -q refs/remotes/origin/HEAD | sed 's#^refs/remotes/origin/##' || true)"
        if [[ -n "$HEAD_BRANCH" ]]; then
          if git -C "$BARE" show-ref --verify --quiet "refs/heads/$BASE_BRANCH"; then
            git -C "$BARE" worktree add "$WT_DIR" "$BASE_BRANCH"
          else
            git -C "$BARE" worktree add --track -b "$BASE_BRANCH" "$WT_DIR" "origin/$HEAD_BRANCH"
          fi
        else
          echo "ERROR: Could not resolve any base branch for $NAME" >&2
          exit 1
        fi
      fi
      echo "Added worktree: $WT_DIR"
    fi
  else
    echo "(Skipping initial worktree creation)"
  fi

  echo
done

echo "Done."

