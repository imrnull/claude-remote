#!/usr/bin/env bash
# output.sh - JSON output formatting for n8n

set -euo pipefail

# Source common utilities if not already loaded
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
[[ -z "${EXIT_SUCCESS:-}" ]] && source "${SCRIPT_DIR}/common.sh"

# Output success JSON
# Arguments: session_id, repo_path, branch_name, claude_response
output_success() {
    local session_id="$1"
    local repo_path="$2"
    local branch_name="$3"
    local claude_response="$4"

    # Use jq to properly escape and format JSON
    jq -n \
        --arg status "success" \
        --arg session_id "$session_id" \
        --arg repo_path "$repo_path" \
        --arg branch_name "$branch_name" \
        --argjson claude_response "$claude_response" \
        '{
            status: $status,
            session_id: $session_id,
            repo_path: $repo_path,
            branch_name: $branch_name,
            claude_response: $claude_response
        }'
}

# Output error JSON
# Arguments: error_code, error_message, [partial_data]
output_error() {
    local error_code="$1"
    local error_message="$2"
    local session_id="${3:-}"
    local repo_path="${4:-}"
    local branch_name="${5:-}"

    jq -n \
        --arg status "error" \
        --arg error_code "$error_code" \
        --arg error_message "$error_message" \
        --arg session_id "$session_id" \
        --arg repo_path "$repo_path" \
        --arg branch_name "$branch_name" \
        '{
            status: $status,
            error_code: ($error_code | tonumber),
            error_message: $error_message,
            session_id: (if $session_id == "" then null else $session_id end),
            repo_path: (if $repo_path == "" then null else $repo_path end),
            branch_name: (if $branch_name == "" then null else $branch_name end)
        }'
}

# Wrap Claude output ensuring valid JSON
# If Claude returns invalid JSON, wrap it as a string
wrap_claude_output() {
    local output="$1"

    # Try to parse as JSON first
    if echo "$output" | jq . >/dev/null 2>&1; then
        echo "$output"
    else
        # Wrap as string if not valid JSON
        jq -n --arg text "$output" '{raw_output: $text}'
    fi
}
