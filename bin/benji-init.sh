#!/usr/bin/env bash
# benji-init.sh - Initialize or continue a Benji coding session
#
# Usage:
#   New session:      benji-init.sh REPO_URL CHAT_ID false WORK_BASE_DIR "task description"
#   Continuation:     benji-init.sh REPO_URL CHAT_ID true WORK_BASE_DIR "user response"
#
# Arguments:
#   REPO_URL      - SSH git URL (e.g., git@github.com:org/repo.git)
#   CHAT_ID       - UUID for the Claude session
#   CONTINUATION  - "true" or "false"
#   WORK_BASE_DIR - Base directory for cloning repositories
#   USER_MESSAGE  - Task description (new session) or response (continuation) - always required
#
# Exit codes:
#   0 - Success
#   1 - Invalid parameters
#   2 - Git operation failed
#   3 - Claude execution failed
#   4 - File/directory not found

set -euo pipefail

# Get script directory and load libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/../lib"
CONFIG_DIR="${SCRIPT_DIR}/../config"

# Source all library files
source "${LIB_DIR}/common.sh"
source "${LIB_DIR}/git-operations.sh"
source "${LIB_DIR}/claude-session.sh"
source "${LIB_DIR}/output.sh"

# Main function
main() {
    local repo_path=""
    local branch_name=""
    local claude_output=""

    # Parse and validate arguments
    if ! parse_args "$@"; then
        output_error "$EXIT_INVALID_PARAMS" "Invalid parameters provided"
        exit $EXIT_INVALID_PARAMS
    fi

    # Validate work base directory exists
    if ! validate_directory "$WORK_BASE_DIR"; then
        output_error "$EXIT_NOT_FOUND" "Work base directory not found: $WORK_BASE_DIR"
        exit $EXIT_NOT_FOUND
    fi

    # Extract repo name and build path
    local repo_name
    repo_name=$(extract_repo_name "$REPO_URL")
    repo_path="${WORK_BASE_DIR}/${repo_name}"

    if [[ "$CONTINUATION" == "false" ]]; then
        # New session flow
        log_info "Starting new Benji session"

        # Clone the repository
        if ! git_clone_repo "$REPO_URL" "$repo_path"; then
            output_error "$EXIT_GIT_FAILED" "Failed to clone repository" "$CHAT_ID" "$repo_path"
            exit $EXIT_GIT_FAILED
        fi

        # Generate and create branch
        branch_name=$(generate_benji_branch_name "$CHAT_ID")
        if ! git_create_branch "$repo_path" "$branch_name"; then
            output_error "$EXIT_GIT_FAILED" "Failed to create branch" "$CHAT_ID" "$repo_path"
            exit $EXIT_GIT_FAILED
        fi

        # Run Claude with task description
        local initial_prompt
        initial_prompt="Task: ${USER_MESSAGE}

Explore the repository and ask clarifying questions."
        local system_prompt_file="${CONFIG_DIR}/prompts/benji-init.txt"

        if ! claude_output=$(run_claude_new_session "$CHAT_ID" "$repo_path" "$initial_prompt" "$system_prompt_file"); then
            # Claude may return non-zero but still have useful output
            log_error "Claude returned non-zero exit code"
        fi

        # Ensure we have valid JSON output
        claude_output=$(wrap_claude_output "$claude_output")

    else
        # Continuation flow
        log_info "Continuing Benji session"

        # Verify repo exists
        if [[ ! -d "$repo_path" ]]; then
            output_error "$EXIT_NOT_FOUND" "Repository not found: $repo_path" "$CHAT_ID"
            exit $EXIT_NOT_FOUND
        fi

        # Get current branch
        branch_name=$(git_current_branch "$repo_path")

        # Resume Claude session
        if ! claude_output=$(resume_claude_session "$CHAT_ID" "$repo_path" "$USER_MESSAGE"); then
            log_error "Claude returned non-zero exit code"
        fi

        # Ensure we have valid JSON output
        claude_output=$(wrap_claude_output "$claude_output")
    fi

    # Output success response
    output_success "$CHAT_ID" "$repo_path" "$branch_name" "$claude_output"
}

# Run main function
main "$@"
