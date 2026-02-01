#!/usr/bin/env bash
# output.sh - JSON output formatting for n8n

set -euo pipefail

# Source common utilities if not already loaded
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
[[ -z "${EXIT_SUCCESS:-}" ]] && source "${SCRIPT_DIR}/common.sh"

# Check if Claude response contains AWAITING_USER_INPUT marker
# Arguments: claude_response_json
check_awaiting_input() {
    local claude_response="$1"

    # Extract the result text from Claude's JSON response
    local result_text
    result_text=$(echo "$claude_response" | jq -r '.result // empty' 2>/dev/null)

    # Check for the marker
    if [[ "$result_text" == *"AWAITING_USER_INPUT: true"* ]]; then
        echo "true"
    else
        echo "false"
    fi
}

# Output success JSON
# Arguments: chat_id, branch_name, working_dir, claude_response
output_success() {
    local chat_id="$1"
    local branch_name="$2"
    local working_dir="$3"
    local claude_response="$4"

    # Check if awaiting user input
    local awaiting_input
    awaiting_input=$(check_awaiting_input "$claude_response")

    # Use jq to properly escape and format JSON
    jq -n \
        --arg status "success" \
        --arg chat_id "$chat_id" \
        --arg branch_name "$branch_name" \
        --arg working_dir "$working_dir" \
        --argjson awaiting_user_input "$awaiting_input" \
        --argjson claude_response "$claude_response" \
        '{
            status: $status,
            chat_id: $chat_id,
            branch_name: $branch_name,
            working_dir: $working_dir,
            awaiting_user_input: $awaiting_user_input,
            claude_response: $claude_response
        }'
}

# Output error JSON
# Arguments: error_code, error_message, [chat_id], [branch_name], [working_dir]
output_error() {
    local error_code="$1"
    local error_message="$2"
    local chat_id="${3:-}"
    local branch_name="${4:-}"
    local working_dir="${5:-}"

    jq -n \
        --arg status "error" \
        --arg error_code "$error_code" \
        --arg error_message "$error_message" \
        --arg chat_id "$chat_id" \
        --arg branch_name "$branch_name" \
        --arg working_dir "$working_dir" \
        '{
            status: $status,
            error_code: ($error_code | tonumber),
            error_message: $error_message,
            chat_id: (if $chat_id == "" then null else $chat_id end),
            branch_name: (if $branch_name == "" then null else $branch_name end),
            working_dir: (if $working_dir == "" then null else $working_dir end)
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
