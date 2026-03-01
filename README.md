# Outline Git Sync

## Scripts

### `export_all_collections.sh`

Exports the current Outline workspace as `outline-markdown`, downloads the archive, and extracts it to a local directory.

Reads these environment variables:

- `OUTLINE_API_KEY` (required)
- `OUTLINE_BASE_URL` default `https://app.getoutline.com`
- `FORMAT` default `outline-markdown`
- `INCLUDE_ATTACHMENTS` default `true`
- `INCLUDE_PRIVATE` default `true`
- `OUTPUT_PATH` default `$(pwd)/outline-export.zip`
- `EXTRACT_DIR` default `$(pwd)/outline-export`
- `POLL_INTERVAL_SECONDS` default `5`
- `TIMEOUT_SECONDS` default `900`
- `CLEANUP_FILE_OPERATION` default `0`
- `DEBUG` default `0`

### `export_all_to_git.sh`

Clones the target Git repo into `OUTLINE_SYNC_DIR`, exports the Outline workspace into a temporary staging directory inside that clone, syncs the exported files into the repo, commits, and pushes.

Reads these environment variables:

- `OUTLINE_API_KEY` (required)
- `OUTLINE_GIT_REMOTE` (required)
- `OUTLINE_SYNC_DIR` (required)
- `OUTLINE_GIT_BRANCH` default current branch of the cloned repo
- `GIT_AUTHOR_NAME` default `Outline Sync`
- `GIT_AUTHOR_EMAIL` default `outline-sync@local`
- `COMMIT_MESSAGE` default `Outline export YYYY-MM-DD HH:MM:SS`
- `DEBUG` default `0`

Also passes through these export settings to `export_all_collections.sh`:

- `OUTLINE_BASE_URL` default `https://app.getoutline.com`
- `FORMAT` default `outline-markdown`
- `INCLUDE_ATTACHMENTS` default `true`
- `INCLUDE_PRIVATE` default `true`
- `POLL_INTERVAL_SECONDS` default `5`
- `TIMEOUT_SECONDS` default `900`
- `CLEANUP_FILE_OPERATION` default `0`
