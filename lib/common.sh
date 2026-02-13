#!/usr/bin/env bash
# common.sh - Core utilities for claude-remote scripts

set -euo pipefail

# Exit codes
readonly EXIT_SUCCESS=0
readonly EXIT_INVALID_PARAMS=1
readonly EXIT_GIT_FAILED=2
readonly EXIT_CLAUDE_FAILED=3
readonly EXIT_NOT_FOUND=4

# Load .env configuration
# Looks for .env in the project root (relative to this script's location)
load_env() {
    local env_file
    env_file="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/.env"

    if [[ ! -f "$env_file" ]]; then
        PARSE_ERROR=".env file not found at: $env_file"
        return $EXIT_NOT_FOUND
    fi

    set -a
    source "$env_file"
    set +a

    if [[ -z "${ROOT_DIR:-}" ]]; then
        PARSE_ERROR="ROOT_DIR not set in .env"
        return $EXIT_INVALID_PARAMS
    fi

    if [[ ! -d "$ROOT_DIR" ]]; then
        PARSE_ERROR="ROOT_DIR directory does not exist: $ROOT_DIR"
        return $EXIT_NOT_FOUND
    fi

    DEFAULT_SOURCE_BRANCH="${DEFAULT_SOURCE_BRANCH:-main}"

    export ROOT_DIR DEFAULT_SOURCE_BRANCH
}

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

validate_branch_name() {
    local name="$1"
    # Branch names: alphanumeric, hyphens, underscores (no spaces or special chars)
    local branch_regex='^[a-zA-Z0-9_-]+$'

    [[ "$name" =~ $branch_regex ]]
}

validate_repo_relative_path() {
    local path="$1"
    # Must contain at least one "/" and only alphanumeric, hyphens, underscores, dots, slashes
    local path_regex='^[a-zA-Z0-9._-]+/[a-zA-Z0-9._-]+(/[a-zA-Z0-9._-]+)*$'

    [[ "$path" =~ $path_regex ]]
}

# Path derivation functions

# Derive org and repo name from REPO_RELATIVE_PATH
# Arguments: repo_relative_path (e.g., "Benji/react-app")
# Sets: REPO_ORG, REPO_NAME, MAIN_REPO_DIR
derive_repo_paths() {
    local repo_relative_path="$1"

    REPO_ORG="${repo_relative_path%/*}"
    REPO_NAME="${repo_relative_path##*/}"
    MAIN_REPO_DIR="${ROOT_DIR}/${repo_relative_path}"

    export REPO_ORG REPO_NAME MAIN_REPO_DIR
}

# Derive the worktree directory path
# Arguments: repo_relative_path, branch_name
derive_worktree_path() {
    local repo_relative_path="$1"
    local branch_name="$2"

    local org="${repo_relative_path%/*}"
    local repo_name="${repo_relative_path##*/}"

    echo "${ROOT_DIR}/${org}/agents/${repo_name}/${branch_name}"
}

# Derive commit prefix from branch name
derive_commit_prefix() {
    local branch_name="$1"
    echo "${branch_name} - "
}

# Parse arguments for main.sh
# Usage: parse_args "$@"
# Sets: CHAT_ID, REPO_RELATIVE_PATH, BRANCH_NAME, SOURCE_BRANCH, PROMPT, COMMIT_PREFIX
#       MAIN_REPO_DIR, WORKTREE_DIR, REPO_ORG, REPO_NAME
# Note: PROMPT is expected as base64-encoded and will be decoded
# Returns: exit code and sets PARSE_ERROR with message on failure
parse_args() {
    CHAT_ID="${1:-}"
    REPO_RELATIVE_PATH="${2:-}"
    BRANCH_NAME="${3:-}"
    SOURCE_BRANCH="${4:-${DEFAULT_SOURCE_BRANCH:-main}}"
    PROMPT="${5:-}"
    PARSE_ERROR=""

    # Validate required params
    if ! validate_required "CHAT_ID" "$CHAT_ID"; then
        PARSE_ERROR="Missing required parameter: CHAT_ID"
        return $EXIT_INVALID_PARAMS
    fi
    if ! validate_required "REPO_RELATIVE_PATH" "$REPO_RELATIVE_PATH"; then
        PARSE_ERROR="Missing required parameter: REPO_RELATIVE_PATH"
        return $EXIT_INVALID_PARAMS
    fi
    if ! validate_required "BRANCH_NAME" "$BRANCH_NAME"; then
        PARSE_ERROR="Missing required parameter: BRANCH_NAME"
        return $EXIT_INVALID_PARAMS
    fi
    if ! validate_required "PROMPT" "$PROMPT"; then
        PARSE_ERROR="Missing required parameter: PROMPT"
        return $EXIT_INVALID_PARAMS
    fi

    # Format validations
    if ! validate_uuid "$CHAT_ID"; then
        PARSE_ERROR="Invalid UUID format: CHAT_ID"
        return $EXIT_INVALID_PARAMS
    fi
    if ! validate_repo_relative_path "$REPO_RELATIVE_PATH"; then
        PARSE_ERROR="Invalid REPO_RELATIVE_PATH: must be in 'org/repo' format (e.g., Benji/react-app)"
        return $EXIT_INVALID_PARAMS
    fi
    if ! validate_branch_name "$BRANCH_NAME"; then
        PARSE_ERROR="Invalid branch name: BRANCH_NAME (use alphanumeric, hyphens, underscores only)"
        return $EXIT_INVALID_PARAMS
    fi

    # Decode base64-encoded PROMPT
    if ! PROMPT=$(echo "$PROMPT" | base64 -d 2>/dev/null); then
        PARSE_ERROR="Invalid base64 encoding for PROMPT"
        return $EXIT_INVALID_PARAMS
    fi

    # Derive paths
    derive_repo_paths "$REPO_RELATIVE_PATH"
    WORKTREE_DIR=$(derive_worktree_path "$REPO_RELATIVE_PATH" "$BRANCH_NAME")
    COMMIT_PREFIX=$(derive_commit_prefix "$BRANCH_NAME")

    # Validate main repo exists
    if [[ ! -d "$MAIN_REPO_DIR" ]]; then
        PARSE_ERROR="Main repository not found: $MAIN_REPO_DIR"
        return $EXIT_NOT_FOUND
    fi

    export CHAT_ID REPO_RELATIVE_PATH BRANCH_NAME SOURCE_BRANCH PROMPT
    export COMMIT_PREFIX MAIN_REPO_DIR WORKTREE_DIR REPO_ORG REPO_NAME
}
