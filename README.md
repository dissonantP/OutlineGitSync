# Outline Git Sync

This repo provides some scripts to export full workspace data from [Outline](https://www.getoutline.com/) and back it up using version control on Github.

It is a one-way sync only (Outline => Local or Outline => Github), and does _not_ support updating your Outline database.

If you want to update Outline, [they offer an API](https://www.getoutline.com/developers) and there's also an MCP out there. 

## Scripts

### `export_all_collections.sh`

Exports the current Outline workspace as `outline-markdown`, downloads the archive, and extracts it to a local directory.

| Name | Meaning | Default |
| --- | --- | --- |
| `OUTLINE_API_KEY` | Bearer token used for Outline API requests. | Required |
| `OUTLINE_BASE_URL` | Base URL for the Outline instance. | `https://app.getoutline.com` |
| `FORMAT` | Export format sent to the Outline export API. | `outline-markdown` |
| `INCLUDE_ATTACHMENTS` | Whether attachments should be included in the export archive. | `true` |
| `INCLUDE_PRIVATE` | Whether private collections and docs should be included. | `true` |
| `OUTPUT_PATH` | Path for the downloaded export ZIP before extraction. | `$HOME/outline-export.zip` |
| `EXTRACT_DIR` | Directory where the export ZIP is extracted. | `$HOME/outline-export` |
| `POLL_INTERVAL_SECONDS` | Seconds between status checks while waiting for the export to finish. | `5` |
| `TIMEOUT_SECONDS` | Max time to wait for the export job before failing. | `900` |
| `CLEANUP_FILE_OPERATION` | Whether to delete the Outline file operation after a successful download. Use `1` to delete it, `0` to leave it in Outline. | `0` |
| `DEBUG` | Whether to print verbose request and response debugging output. Use `1` to enable it. | `0` |

### `export_all_to_git.sh`

Clones the target Git repo into `OUTLINE_SYNC_DIR`, exports the Outline workspace into a temporary staging directory inside that clone, syncs the exported files into the repo, commits, and pushes.

| Name | Meaning | Default |
| --- | --- | --- |
| `OUTLINE_API_KEY` | Passed through to `export_all_collections.sh` for Outline API access. | Required |
| `OUTLINE_GIT_REMOTE` | Git remote URL to clone from and push back to. | Required |
| `OUTLINE_SYNC_DIR` | Directory where the repo is cloned and synced. | Required |
| `OUTLINE_GIT_BRANCH` | Branch to clone and push. If unset, the script uses the cloned repo's current branch. | Current branch of the cloned repo |
| `GIT_AUTHOR_NAME` | Git author name for the generated commit. | `Outline Sync` |
| `GIT_AUTHOR_EMAIL` | Git author email for the generated commit. | `outline-sync@local` |
| `COMMIT_MESSAGE` | Commit message used when exported content changes. | `Outline export YYYY-MM-DD HH:MM:SS` |
| `DEBUG` | Whether to print verbose sync logging. Use `1` to enable it. | `0` |

Also passes through these export settings to `export_all_collections.sh`:

| Name | Meaning | Default |
| --- | --- | --- |
| `OUTLINE_BASE_URL` | Base URL for the Outline instance. | `https://app.getoutline.com` |
| `FORMAT` | Export format sent to the Outline export API. | `outline-markdown` |
| `INCLUDE_ATTACHMENTS` | Whether attachments should be included in the export archive. | `true` |
| `INCLUDE_PRIVATE` | Whether private collections and docs should be included. | `true` |
| `POLL_INTERVAL_SECONDS` | Seconds between status checks while waiting for the export to finish. | `5` |
| `TIMEOUT_SECONDS` | Max time to wait for the export job before failing. | `900` |
| `CLEANUP_FILE_OPERATION` | Whether to delete the Outline file operation after a successful download. Use `1` to delete it, `0` to leave it in Outline. | `0` |
