#!/usr/bin/env bash
# obsidian.sh - Obsidian vault functions for claude-remote

set -euo pipefail

# Source common utilities if not already loaded
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
[[ -z "${EXIT_SUCCESS:-}" ]] && source "${SCRIPT_DIR}/common.sh"

# Validate vault name - alphanumeric, hyphens, underscores, spaces
# Arguments: vault_name
validate_vault_name() {
    local name="$1"
    local vault_regex='^[a-zA-Z0-9 _-]+$'

    [[ "$name" =~ $vault_regex ]]
}

# Derive Obsidian paths from vault name
# Arguments: vault_name, chat_id
# Sets: OBSIDIAN_VAULT_DIR, CHATS_DIR, NOTE_PATH
derive_obsidian_paths() {
    local vault_name="$1"
    local chat_id="$2"

    OBSIDIAN_VAULT_DIR="${OBSIDIAN_VAULTS_DIR}/${vault_name}"
    CHATS_DIR="${OBSIDIAN_VAULT_DIR}/Chats"
    NOTE_PATH="${CHATS_DIR}/${chat_id}.md"

    export OBSIDIAN_VAULT_DIR CHATS_DIR NOTE_PATH
}

# Parse arguments for obsidian-claude
# Usage: parse_obsidian_args "$@"
# Sets: CHAT_ID, VAULT_NAME, PROMPT, OBSIDIAN_VAULT_DIR, CHATS_DIR, NOTE_PATH
# Returns: exit code and sets PARSE_ERROR with message on failure
parse_obsidian_args() {
    CHAT_ID="${1:-}"
    VAULT_NAME="${2:-}"
    PROMPT="${3:-}"
    PARSE_ERROR=""

    # Validate required params
    if ! validate_required "CHAT_ID" "$CHAT_ID"; then
        PARSE_ERROR="Missing required parameter: CHAT_ID"
        return $EXIT_INVALID_PARAMS
    fi
    if ! validate_required "VAULT_NAME" "$VAULT_NAME"; then
        PARSE_ERROR="Missing required parameter: VAULT_NAME"
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
    if ! validate_vault_name "$VAULT_NAME"; then
        PARSE_ERROR="Invalid vault name: VAULT_NAME (use alphanumeric, hyphens, underscores, spaces only)"
        return $EXIT_INVALID_PARAMS
    fi

    # Decode base64-encoded PROMPT
    if ! PROMPT=$(echo "$PROMPT" | base64 -d 2>/dev/null); then
        PARSE_ERROR="Invalid base64 encoding for PROMPT"
        return $EXIT_INVALID_PARAMS
    fi

    # Validate OBSIDIAN_VAULTS_DIR is configured
    if [[ -z "${OBSIDIAN_VAULTS_DIR:-}" ]]; then
        PARSE_ERROR="OBSIDIAN_VAULTS_DIR not set in .env"
        return $EXIT_INVALID_PARAMS
    fi

    # Derive paths
    derive_obsidian_paths "$VAULT_NAME" "$CHAT_ID"

    # Validate vault exists
    if [[ ! -d "$OBSIDIAN_VAULT_DIR" ]]; then
        PARSE_ERROR="Vault not found: $OBSIDIAN_VAULT_DIR"
        return $EXIT_NOT_FOUND
    fi

    export CHAT_ID VAULT_NAME PROMPT
}

# Check if chat note already exists (continuation detection)
# Arguments: note_path
note_exists() {
    local note_path="$1"
    [[ -f "$note_path" ]]
}

# Create Chats directory if it doesn't exist
# Arguments: chats_dir
ensure_chats_dir() {
    local chats_dir="$1"
    if [[ ! -d "$chats_dir" ]]; then
        log_info "Creating Chats directory: $chats_dir"
        mkdir -p "$chats_dir"
    fi
}

# Create skeleton chat note with YAML front-matter
# Arguments: note_path, chat_id
create_skeleton_note() {
    local note_path="$1"
    local chat_id="$2"
    local today
    today=$(date +%Y-%m-%d)

    cat > "$note_path" <<EOF
---
chat_id: ${chat_id}
date: ${today}
tags:
  - chat
---
EOF

    log_info "Created chat note: $note_path"
}

# Extract chat_id from note YAML front-matter
# Arguments: note_path, fallback_chat_id
get_chat_id_from_note() {
    local note_path="$1"
    local fallback="$2"

    if [[ -f "$note_path" ]]; then
        local extracted
        extracted=$(sed -n 's/^chat_id: *//p' "$note_path" 2>/dev/null | head -1)
        if [[ -n "$extracted" ]]; then
            echo "$extracted"
            return
        fi
    fi

    echo "$fallback"
}

# Output success JSON for obsidian sessions
# Arguments: chat_id, note_path, working_dir, claude_response
output_obsidian_success() {
    local chat_id="$1"
    local note_path="$2"
    local working_dir="$3"
    local claude_response="$4"

    # Check if awaiting user input
    local awaiting_input
    awaiting_input=$(check_awaiting_input "$claude_response")

    jq -n \
        --arg status "success" \
        --arg chat_id "$chat_id" \
        --arg note_path "$note_path" \
        --arg working_dir "$working_dir" \
        --argjson awaiting_user_input "$awaiting_input" \
        --argjson claude_response "$claude_response" \
        '{
            status: $status,
            chat_id: $chat_id,
            note_path: $note_path,
            working_dir: $working_dir,
            awaiting_user_input: $awaiting_user_input,
            claude_response: $claude_response
        }'
}

# Output error JSON for obsidian sessions
# Arguments: error_code, error_message, [chat_id], [note_path], [working_dir]
output_obsidian_error() {
    local error_code="$1"
    local error_message="$2"
    local chat_id="${3:-}"
    local note_path="${4:-}"
    local working_dir="${5:-}"

    jq -n \
        --arg status "error" \
        --arg error_code "$error_code" \
        --arg error_message "$error_message" \
        --arg chat_id "$chat_id" \
        --arg note_path "$note_path" \
        --arg working_dir "$working_dir" \
        '{
            status: $status,
            error_code: ($error_code | tonumber),
            error_message: $error_message,
            chat_id: (if $chat_id == "" then null else $chat_id end),
            note_path: (if $note_path == "" then null else $note_path end),
            working_dir: (if $working_dir == "" then null else $working_dir end)
        }'
}
