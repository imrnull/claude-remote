#!/usr/bin/env bash
# common.sh - Core utilities for claude-remote scripts

set -euo pipefail

# Exit codes
readonly EXIT_SUCCESS=0
readonly EXIT_INVALID_PARAMS=1
readonly EXIT_GIT_FAILED=2
readonly EXIT_CLAUDE_FAILED=3
readonly EXIT_NOT_FOUND=4

# Logging functions - all output to stderr to keep stdout clean for JSON
log_info() {
    echo "[INFO] $*" >&2
}

log_error() {
    echo "[ERROR] $*" >&2
}

log_debug() {
    if [[ "${DEBUG:-false}" == "true" ]]; then
        echo "[DEBUG] $*" >&2
    fi
}

# Validation functions
validate_required() {
    local name="$1"
    local value="$2"

    if [[ -z "$value" ]]; then
        log_error "Required parameter '$name' is missing or empty"
        return 1
    fi
}

validate_uuid() {
    local value="$1"
    local uuid_regex='^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'

    if [[ ! "$value" =~ $uuid_regex ]]; then
        log_error "Invalid UUID format: $value"
        return 1
    fi
}

validate_boolean() {
    local name="$1"
    local value="$2"

    if [[ "$value" != "true" && "$value" != "false" ]]; then
        log_error "Parameter '$name' must be 'true' or 'false', got: $value"
        return 1
    fi
}

validate_directory() {
    local path="$1"

    if [[ ! -d "$path" ]]; then
        log_error "Directory does not exist: $path"
        return 1
    fi
}

validate_ssh_url() {
    local url="$1"
    # Matches git@host:path or ssh://git@host/path
    local ssh_regex='^(git@[^:]+:.+\.git|ssh://[^/]+/.+\.git)$'

    if [[ ! "$url" =~ $ssh_regex ]]; then
        log_error "Invalid SSH git URL: $url"
        return 1
    fi
}

# Extract repo name from SSH URL
# git@github.com:org/repo.git -> repo
extract_repo_name() {
    local url="$1"
    local basename

    # Get the last component after : or /
    basename="${url##*/}"
    # Also handle git@host:org/repo.git format
    basename="${basename##*:}"
    # Remove .git suffix
    basename="${basename%.git}"

    echo "$basename"
}

# Parse common arguments
# Usage: parse_args "$@"
# Sets: REPO_URL, CHAT_ID, CONTINUATION, WORK_BASE_DIR, USER_MESSAGE
parse_args() {
    REPO_URL="${1:-}"
    CHAT_ID="${2:-}"
    CONTINUATION="${3:-}"
    WORK_BASE_DIR="${4:-}"
    USER_MESSAGE="${5:-}"

    validate_required "REPO_URL" "$REPO_URL" || return $EXIT_INVALID_PARAMS
    validate_required "CHAT_ID" "$CHAT_ID" || return $EXIT_INVALID_PARAMS
    validate_required "CONTINUATION" "$CONTINUATION" || return $EXIT_INVALID_PARAMS
    validate_required "WORK_BASE_DIR" "$WORK_BASE_DIR" || return $EXIT_INVALID_PARAMS

    validate_ssh_url "$REPO_URL" || return $EXIT_INVALID_PARAMS
    validate_uuid "$CHAT_ID" || return $EXIT_INVALID_PARAMS
    validate_boolean "CONTINUATION" "$CONTINUATION" || return $EXIT_INVALID_PARAMS
    validate_required "USER_MESSAGE" "$USER_MESSAGE" || return $EXIT_INVALID_PARAMS

    # Export for use by other scripts
    export REPO_URL CHAT_ID CONTINUATION WORK_BASE_DIR USER_MESSAGE
}
