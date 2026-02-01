#!/usr/bin/env bash
# claude-session.sh - Claude Code invocation functions

set -euo pipefail

# Source common utilities if not already loaded
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
[[ -z "${EXIT_CLAUDE_FAILED:-}" ]] && source "${SCRIPT_DIR}/common.sh"

# Run Claude in print mode with a new session
# Arguments: session_id, repo_dir, prompt, system_prompt_file
run_claude_new_session() {
    local session_id="$1"
    local repo_dir="$2"
    local prompt="$3"
    local system_prompt_file="$4"

    log_info "Starting new Claude session: $session_id"
    log_debug "Working directory: $repo_dir"

    local claude_output
    local exit_code=0

    # Build the command
    local cmd=(
        claude
        -p
        --session-id "$session_id"
        --output-format json
        --dangerously-skip-permissions
    )

    # Add system prompt if file exists
    if [[ -n "$system_prompt_file" && -f "$system_prompt_file" ]]; then
        cmd+=(--append-system-prompt "$(cat "$system_prompt_file")")
    fi

    # Add the prompt
    cmd+=("$prompt")

    log_debug "Running command: ${cmd[*]}"

    # Run Claude and capture output
    if ! claude_output=$(cd "$repo_dir" && "${cmd[@]}" 2>&2); then
        exit_code=$?
        log_error "Claude exited with code: $exit_code"
        # Still try to return the output even on failure
    fi

    echo "$claude_output"
    return $exit_code
}

# Resume an existing Claude session
# Arguments: session_id, repo_dir, message
resume_claude_session() {
    local session_id="$1"
    local repo_dir="$2"
    local message="$3"

    log_info "Resuming Claude session: $session_id"
    log_debug "Working directory: $repo_dir"

    local claude_output
    local exit_code=0

    # Build the command
    local cmd=(
        claude
        -p
        --resume "$session_id"
        --output-format json
        --dangerously-skip-permissions
        "$message"
    )

    log_debug "Running command: ${cmd[*]}"

    # Run Claude and capture output
    if ! claude_output=$(cd "$repo_dir" && "${cmd[@]}" 2>&2); then
        exit_code=$?
        log_error "Claude exited with code: $exit_code"
    fi

    echo "$claude_output"
    return $exit_code
}
