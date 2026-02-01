#!/usr/bin/env bash
# claude-session.sh - Claude Code invocation functions

set -euo pipefail

# Source common utilities if not already loaded
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
[[ -z "${EXIT_CLAUDE_FAILED:-}" ]] && source "${SCRIPT_DIR}/common.sh"

# Build system prompt from template file
# Arguments: template_file, commit_prefix
build_system_prompt() {
    local template_file="$1"
    local commit_prefix="$2"

    if [[ ! -f "$template_file" ]]; then
        log_debug "System prompt template not found: $template_file"
        return 1
    fi

    local template
    template=$(cat "$template_file")

    # Replace {{COMMIT_PREFIX}} placeholder
    echo "${template//\{\{COMMIT_PREFIX\}\}/$commit_prefix}"
}

# Run Claude in print mode with a new session
# Arguments: session_id, working_dir, prompt, system_prompt_file, commit_prefix
run_claude_new_session() {
    local session_id="$1"
    local working_dir="$2"
    local prompt="$3"
    local system_prompt_file="$4"
    local commit_prefix="${5:-}"

    log_info "Starting new Claude session: $session_id"
    log_debug "Working directory: $working_dir"

    local claude_output
    local exit_code=0

    # Build the command
    local cmd=(
        /home/claude/.local/bin/claude
        -p
        --session-id "$session_id"
        --output-format json
        --dangerously-skip-permissions
    )

    # Add system prompt if file exists
    if [[ -n "$system_prompt_file" && -f "$system_prompt_file" ]]; then
        local system_prompt
        system_prompt=$(build_system_prompt "$system_prompt_file" "$commit_prefix")
        cmd+=(--append-system-prompt "$system_prompt")
    fi

    # Add the prompt
    cmd+=("$prompt")

    log_debug "Running command: ${cmd[*]}"

    # Run Claude and capture output
    if ! claude_output=$(cd "$working_dir" && "${cmd[@]}" 2>&2); then
        exit_code=$?
        log_debug "Claude exited with code: $exit_code"
        # Still try to return the output even on failure
    fi

    echo "$claude_output"
    return $exit_code
}

# Resume an existing Claude session
# Arguments: session_id, working_dir, message
resume_claude_session() {
    local session_id="$1"
    local working_dir="$2"
    local message="$3"

    log_info "Resuming Claude session: $session_id"
    log_debug "Working directory: $working_dir"

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
    if ! claude_output=$(cd "$working_dir" && "${cmd[@]}" 2>&2); then
        exit_code=$?
        log_debug "Claude exited with code: $exit_code"
    fi

    echo "$claude_output"
    return $exit_code
}
