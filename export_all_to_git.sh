#!/usr/bin/env bash
set -euo pipefail

: "${OUTLINE_API_KEY:?Set OUTLINE_API_KEY in your environment}"
: "${OUTLINE_GIT_REMOTE:?Set OUTLINE_GIT_REMOTE in your environment}"
: "${OUTLINE_SYNC_DIR:?Set OUTLINE_SYNC_DIR in your environment}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXPORT_SCRIPT="${SCRIPT_DIR}/export_all_collections.sh"

OUTLINE_GIT_BRANCH="${OUTLINE_GIT_BRANCH:-}"
GIT_AUTHOR_NAME="${GIT_AUTHOR_NAME:-Outline Sync}"
GIT_AUTHOR_EMAIL="${GIT_AUTHOR_EMAIL:-outline-sync@local}"
COMMIT_MESSAGE="${COMMIT_MESSAGE:-Outline export $(date '+%Y-%m-%d %H:%M:%S')}"
DEBUG="${DEBUG:-0}"
REPO_DIR="$OUTLINE_SYNC_DIR"

if [[ ! -x "$EXPORT_SCRIPT" ]]; then
  echo "Expected executable export script at $EXPORT_SCRIPT" >&2
  exit 1
fi

if ! command -v git >/dev/null 2>&1; then
  echo "git is required but not installed." >&2
  exit 1
fi

if ! command -v rsync >/dev/null 2>&1; then
  echo "rsync is required but not installed." >&2
  exit 1
fi

log() {
  printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >&2
}

cleanup() {
  if [[ -n "${staging_dir:-}" && -d "${staging_dir:-}" ]]; then
    rm -rf "$staging_dir"
  fi
}
trap cleanup EXIT

export_dir=""
staging_dir=""

repo_dir="$REPO_DIR"

if [[ "$repo_dir" != /* ]]; then
  repo_dir="${SCRIPT_DIR}/${repo_dir}"
fi

if [[ "$repo_dir" == "/" ]]; then
  echo "OUTLINE_SYNC_DIR must not be /." >&2
  exit 1
fi

mkdir -p "$(dirname "$repo_dir")"
rm -rf "$repo_dir"

if [[ -n "$OUTLINE_GIT_BRANCH" ]]; then
  log "Cloning $OUTLINE_GIT_REMOTE on branch $OUTLINE_GIT_BRANCH"
  git clone --branch "$OUTLINE_GIT_BRANCH" "$OUTLINE_GIT_REMOTE" "$repo_dir"
else
  log "Cloning $OUTLINE_GIT_REMOTE"
  git clone "$OUTLINE_GIT_REMOTE" "$repo_dir"
fi

git -C "$repo_dir" remote set-url origin "$OUTLINE_GIT_REMOTE"
git -C "$repo_dir" remote set-url --push origin "$OUTLINE_GIT_REMOTE"

if [[ -z "$OUTLINE_GIT_BRANCH" ]]; then
  OUTLINE_GIT_BRANCH="$(git -C "$repo_dir" symbolic-ref --short HEAD)"
fi

if [[ "$DEBUG" == "1" ]]; then
  log "Preparing export staging inside $repo_dir"
fi

staging_dir="$(mktemp -d "${repo_dir%/}/.outline-sync-export.XXXXXX")"
export_dir="${staging_dir}/extract"

log "Running Outline export"
OUTPUT_PATH="${staging_dir}/export.zip" EXTRACT_DIR="$export_dir" "$EXPORT_SCRIPT" >/dev/null

if [[ ! -d "$export_dir" ]]; then
  echo "Export script did not produce a directory: $export_dir" >&2
  exit 1
fi

log "Using git worktree $(git -C "$repo_dir" rev-parse --show-toplevel)"
log "Using git fetch remote $(git -C "$repo_dir" remote get-url origin)"
log "Using git push remote $(git -C "$repo_dir" remote get-url --push origin)"

find "$repo_dir" -mindepth 1 -maxdepth 1 ! -name '.git' ! -name "$(basename "$staging_dir")" -exec rm -rf {} +
rsync -a --delete --exclude='.git' --exclude="$(basename "$staging_dir")" "${export_dir}/" "${repo_dir}/"

if [[ ! -d "$repo_dir/.git" ]]; then
  echo "Repository metadata was lost during sync: $repo_dir/.git is missing." >&2
  exit 1
fi

rm -rf "$staging_dir"
staging_dir=""

git -C "$repo_dir" config user.name "$GIT_AUTHOR_NAME"
git -C "$repo_dir" config user.email "$GIT_AUTHOR_EMAIL"
git -C "$repo_dir" add -A

if git -C "$repo_dir" diff --cached --quiet --ignore-submodules --; then
  log "No changes to commit"
  printf '%s\n' "No changes"
  exit 0
fi

git -C "$repo_dir" commit -m "$COMMIT_MESSAGE"

log "Pushing commit to $OUTLINE_GIT_BRANCH"
git -C "$repo_dir" push origin "HEAD:${OUTLINE_GIT_BRANCH}"

printf '%s\n' "$(git -C "$repo_dir" rev-parse HEAD)"
