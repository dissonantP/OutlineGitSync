#!/usr/bin/env bash
set -euo pipefail

: "${OUTLINE_API_KEY:?Set OUTLINE_API_KEY in your environment}"

BASE_URL="${OUTLINE_BASE_URL:-https://app.getoutline.com}"
EXPORT_URL="${BASE_URL%/}/api/collections.export_all"
FILE_INFO_URL="${BASE_URL%/}/api/fileOperations.info"
FILE_REDIRECT_URL="${BASE_URL%/}/api/fileOperations.redirect"
FILE_DELETE_URL="${BASE_URL%/}/api/fileOperations.delete"

FORMAT="${FORMAT:-outline-markdown}"
INCLUDE_ATTACHMENTS="${INCLUDE_ATTACHMENTS:-true}"
INCLUDE_PRIVATE="${INCLUDE_PRIVATE:-true}"
OUTPUT_PATH="${OUTPUT_PATH:-}"
EXTRACT_DIR="${EXTRACT_DIR:-}"
POLL_INTERVAL_SECONDS="${POLL_INTERVAL_SECONDS:-5}"
TIMEOUT_SECONDS="${TIMEOUT_SECONDS:-900}"
CLEANUP_FILE_OPERATION="${CLEANUP_FILE_OPERATION:-0}"
DEBUG="${DEBUG:-0}"

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required but not installed." >&2
  exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
  echo "curl is required but not installed." >&2
  exit 1
fi

if ! command -v ditto >/dev/null 2>&1 && ! command -v unzip >/dev/null 2>&1; then
  echo "Either ditto or unzip is required but neither is installed." >&2
  exit 1
fi

log() {
  printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >&2
}

preview_token() {
  printf '%s...%s' "${OUTLINE_API_KEY:0:6}" "${OUTLINE_API_KEY: -4}"
}

api_post() {
  local url="$1"
  local payload="$2"
  local response_file
  local http_code

  response_file=$(mktemp)

  if [[ "$DEBUG" == "1" ]]; then
    log "POST $url"
    jq . <<<"$payload" >&2
  fi

  http_code=$(curl \
    --silent --show-error \
    --output "$response_file" \
    --write-out '%{http_code}' \
    "$url" \
    --request POST \
    --header 'Accept: application/json' \
    --header 'Content-Type: application/json' \
    --header "Authorization: Bearer ${OUTLINE_API_KEY}" \
    --data "$payload")

  if [[ "$DEBUG" == "1" ]]; then
    log "HTTP $http_code from $url"
    cat "$response_file" >&2
    echo >&2
  fi

  if [[ "$http_code" -lt 200 || "$http_code" -ge 300 ]]; then
    echo "HTTP $http_code from $url" >&2
    cat "$response_file" >&2
    echo >&2
    rm -f "$response_file"
    exit 1
  fi

  cat "$response_file"
  rm -f "$response_file"
}

download_file_operation() {
  local file_operation_id="$1"
  local destination="$2"
  local redirect_headers_file
  local download_headers_file
  local redirect_url
  local http_code

  redirect_headers_file=$(mktemp)
  download_headers_file=$(mktemp)
  mkdir -p "$(dirname "$destination")"

  http_code=$(curl \
    --silent --show-error \
    --dump-header "$redirect_headers_file" \
    --write-out '%{http_code}' \
    "${FILE_REDIRECT_URL}" \
    --request POST \
    --header "Authorization: Bearer ${OUTLINE_API_KEY}" \
    --header 'Content-Type: application/json' \
    --header 'Accept: application/octet-stream,application/zip,application/json' \
    --data "$(jq -n --arg id "$file_operation_id" '{id: $id}')" \
    --output /dev/null)

  if [[ "$http_code" -lt 200 || "$http_code" -ge 400 ]]; then
    echo "HTTP $http_code while retrieving redirect for file operation $file_operation_id" >&2
    cat "$redirect_headers_file" >&2
    echo >&2
    rm -f "$redirect_headers_file" "$download_headers_file"
    exit 1
  fi

  redirect_url=$(awk 'BEGIN{IGNORECASE=1} /^location:/ { sub(/\r$/, "", $2); print $2 }' "$redirect_headers_file" | tail -n 1)
  if [[ -z "$redirect_url" ]]; then
    echo "No redirect URL returned for file operation $file_operation_id." >&2
    cat "$redirect_headers_file" >&2
    echo >&2
    rm -f "$redirect_headers_file" "$download_headers_file"
    exit 1
  fi

  http_code=$(curl \
    --silent --show-error --location \
    --dump-header "$download_headers_file" \
    --write-out '%{http_code}' \
    "$redirect_url" \
    --output "$destination")

  if [[ "$http_code" -lt 200 || "$http_code" -ge 400 ]]; then
    echo "HTTP $http_code while downloading redirected file for operation $file_operation_id" >&2
    cat "$download_headers_file" >&2
    echo >&2
    rm -f "$redirect_headers_file" "$download_headers_file"
    exit 1
  fi

  printf '%s\n' "$destination"
  rm -f "$redirect_headers_file" "$download_headers_file"
}

delete_file_operation() {
  local file_operation_id="$1"
  api_post "$FILE_DELETE_URL" "$(jq -n --arg id "$file_operation_id" '{id: $id}')" >/dev/null
}

extract_archive() {
  local archive_path="$1"
  local destination="$2"

  mkdir -p "$destination"

  if command -v ditto >/dev/null 2>&1; then
    ditto -x -k "$archive_path" "$destination"
    return
  fi

  # BSD unzip on macOS is sensitive to non-UTF-8 locales.
  LC_ALL="${LC_ALL:-en_US.UTF-8}" LANG="${LANG:-en_US.UTF-8}" unzip -q "$archive_path" -d "$destination"
}

export_payload=$(jq -n \
  --arg format "$FORMAT" \
  --argjson includeAttachments "$INCLUDE_ATTACHMENTS" \
  --argjson includePrivate "$INCLUDE_PRIVATE" \
  '{
    format: $format,
    includeAttachments: $includeAttachments,
    includePrivate: $includePrivate
  }')

if [[ "$DEBUG" == "1" ]]; then
  log "Using Outline token $(preview_token)"
fi

log "Starting workspace export"
start_response=$(api_post "$EXPORT_URL" "$export_payload")
file_operation_id=$(jq -r '.data.id // .id // .data.fileOperation.id // empty' <<<"$start_response")

if [[ -z "$file_operation_id" ]]; then
  echo "Unable to find file operation id in export response." >&2
  echo "$start_response" >&2
  exit 1
fi

log "Export queued as file operation $file_operation_id"

if [[ -z "$OUTPUT_PATH" ]]; then
  OUTPUT_PATH="$(pwd)/outline-export.zip"
fi

if [[ -z "$EXTRACT_DIR" ]]; then
  EXTRACT_DIR="$(pwd)/outline-export"
fi

rm -f "$OUTPUT_PATH"
rm -rf "$EXTRACT_DIR"

deadline=$(( $(date +%s) + TIMEOUT_SECONDS ))
state=""
size=""

while :; do
  now=$(date +%s)
  if (( now > deadline )); then
    echo "Timed out waiting for export $file_operation_id after ${TIMEOUT_SECONDS}s." >&2
    exit 1
  fi

  info_response=$(api_post "$FILE_INFO_URL" "$(jq -n --arg id "$file_operation_id" '{id: $id}')")
  state=$(jq -r '.data.state // .state // empty' <<<"$info_response")
  size=$(jq -r '.data.size // .size // empty' <<<"$info_response")

  case "$state" in
    complete|completed)
      log "Export completed${size:+ (${size} bytes)}"
      break
      ;;
    error|failed|canceled|cancelled)
      echo "Export $file_operation_id ended in state '$state'." >&2
      echo "$info_response" >&2
      exit 1
      ;;
    *)
      log "Waiting for export $file_operation_id${state:+ (state: $state)}"
      sleep "$POLL_INTERVAL_SECONDS"
      ;;
  esac
done

log "Downloading export archive"
downloaded_file=$(download_file_operation "$file_operation_id" "$OUTPUT_PATH")

if [[ ! -s "$downloaded_file" ]]; then
  echo "Download finished but '$downloaded_file' is missing or empty." >&2
  exit 1
fi

log "Extracting archive to $EXTRACT_DIR"
extract_archive "$downloaded_file" "$EXTRACT_DIR"
rm -f "$downloaded_file"

if [[ "$CLEANUP_FILE_OPERATION" == "1" ]]; then
  log "Deleting file operation $file_operation_id"
  delete_file_operation "$file_operation_id"
fi

printf '%s\n' "$EXTRACT_DIR"
