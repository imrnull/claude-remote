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
# Only used for debug/info, NOT for errors that go to JSON
log_info() {
    echo "[INFO] $*" >&2
}

log_debug() {
    if [[ "${DEBUG:-false}" == "true" ]]; then
        echo "[DEBUG] $*" >&2
    fi
}

# Validation functions - return silently, errors communicated via JSON
validate_required() {
    local name="$1"
    local value="$2"

    [[ -n "$value" ]]
}

validate_uuid() {
    local value="$1"
    local uuid_regex='^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'

    [[ "$value" =~ $uuid_regex ]]
}

validate_directory() {
    local path="$1"

    [[ -d "$path" ]]
}

validate_ssh_url() {
    local url="$1"
    # Matches git@host:path or ssh://git@host/path
    local ssh_regex='^(git@[^:]+:.+\.git|ssh://[^/]+/.+\.git)$'

    [[ "$url" =~ $ssh_regex ]]
}

validate_branch_name() {
    local name="$1"
    # Branch names: alphanumeric, hyphens, underscores (no spaces or special chars)
    local branch_regex='^[a-zA-Z0-9_-]+$'

    [[ "$name" =~ $branch_regex ]]
}

# Parse arguments for benji-init
# Usage: parse_args "$@"
# Sets: CHAT_ID, REPO_URL, WORK_BASE_DIR, BRANCH_NAME, COMMIT_PREFIX, PROMPT
# Returns: exit code and sets PARSE_ERROR with message on failure
parse_args() {
    CHAT_ID="${1:-}"
    REPO_URL="${2:-}"
    WORK_BASE_DIR="${3:-}"
    BRANCH_NAME="${4:-}"
    COMMIT_PREFIX="${5:-}"
    PROMPT="${6:-}"
    PARSE_ERROR=""

    if ! validate_required "CHAT_ID" "$CHAT_ID"; then
        PARSE_ERROR="Missing required parameter: CHAT_ID"
        return $EXIT_INVALID_PARAMS
    fi
    if ! validate_required "REPO_URL" "$REPO_URL"; then
        PARSE_ERROR="Missing required parameter: REPO_URL"
        return $EXIT_INVALID_PARAMS
    fi
    if ! validate_required "WORK_BASE_DIR" "$WORK_BASE_DIR"; then
        PARSE_ERROR="Missing required parameter: WORK_BASE_DIR"
        return $EXIT_INVALID_PARAMS
    fi
    if ! validate_required "BRANCH_NAME" "$BRANCH_NAME"; then
        PARSE_ERROR="Missing required parameter: BRANCH_NAME"
        return $EXIT_INVALID_PARAMS
    fi
    # COMMIT_PREFIX can be empty
    if ! validate_required "PROMPT" "$PROMPT"; then
        PARSE_ERROR="Missing required parameter: PROMPT"
        return $EXIT_INVALID_PARAMS
    fi

    if ! validate_uuid "$CHAT_ID"; then
        PARSE_ERROR="Invalid UUID format: CHAT_ID"
        return $EXIT_INVALID_PARAMS
    fi
    if ! validate_ssh_url "$REPO_URL"; then
        PARSE_ERROR="Invalid SSH git URL: REPO_URL"
        return $EXIT_INVALID_PARAMS
    fi
    if ! validate_branch_name "$BRANCH_NAME"; then
        PARSE_ERROR="Invalid branch name: BRANCH_NAME (use alphanumeric, hyphens, underscores only)"
        return $EXIT_INVALID_PARAMS
    fi

    # Export for use by other scripts
    export CHAT_ID REPO_URL WORK_BASE_DIR BRANCH_NAME COMMIT_PREFIX PROMPT
}
