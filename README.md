# Outline Git Sync

## Scripts

### `export_all_collections.sh`

Exports the current Outline workspace as `outline-markdown`, downloads the archive, and extracts it to a local directory.

Reads these environment variables:

- `OUTLINE_API_KEY` (required)
- `OUTLINE_BASE_URL`
- `FORMAT`
- `INCLUDE_ATTACHMENTS`
- `INCLUDE_PRIVATE`
- `OUTPUT_PATH`
- `EXTRACT_DIR`
- `POLL_INTERVAL_SECONDS`
- `TIMEOUT_SECONDS`
- `CLEANUP_FILE_OPERATION`
- `DEBUG`

### `export_all_to_git.sh`

Clones the target Git repo into `OUTLINE_SYNC_DIR`, exports the Outline workspace into a temporary staging directory inside that clone, syncs the exported files into the repo, commits, and pushes.

Reads these environment variables:

- `OUTLINE_API_KEY` (required)
- `OUTLINE_GIT_REMOTE` (required)
- `OUTLINE_SYNC_DIR` (required)
- `OUTLINE_GIT_BRANCH`
- `GIT_AUTHOR_NAME`
- `GIT_AUTHOR_EMAIL`
- `COMMIT_MESSAGE`
- `DEBUG`

Also passes through these export settings to `export_all_collections.sh`:

- `OUTLINE_BASE_URL`
- `FORMAT`
- `INCLUDE_ATTACHMENTS`
- `INCLUDE_PRIVATE`
- `POLL_INTERVAL_SECONDS`
- `TIMEOUT_SECONDS`
- `CLEANUP_FILE_OPERATION`
