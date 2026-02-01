#!/usr/bin/env bash
# git-operations.sh - Git clone and branch operations

set -euo pipefail

# Source common utilities if not already loaded
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
[[ -z "${EXIT_GIT_FAILED:-}" ]] && source "${SCRIPT_DIR}/common.sh"

# Generate branch name for Benji
# Format: benji/YYYYMMDD-HHMMSS-{first8charsOfUUID}
generate_benji_branch_name() {
    local chat_id="$1"
    local timestamp
    local uuid_prefix

    timestamp=$(date +"%Y%m%d-%H%M%S")
    uuid_prefix="${chat_id:0:8}"

    echo "benji/${timestamp}-${uuid_prefix}"
}

# Clone a repository
# Arguments: repo_url, target_dir
git_clone_repo() {
    local repo_url="$1"
    local target_dir="$2"

    log_info "Cloning repository: $repo_url"
    log_debug "Target directory: $target_dir"

    if [[ -d "$target_dir" ]]; then
        log_info "Repository already exists at $target_dir, pulling latest changes"
        if ! git -C "$target_dir" fetch --all 2>&2; then
            log_error "Failed to fetch updates for existing repository"
            return $EXIT_GIT_FAILED
        fi
        if ! git -C "$target_dir" checkout main 2>&2 || ! git -C "$target_dir" checkout master 2>&2; then
            log_debug "Could not checkout main/master, staying on current branch"
        fi
        if ! git -C "$target_dir" pull 2>&2; then
            log_debug "Pull failed, continuing with existing state"
        fi
    else
        if ! git clone "$repo_url" "$target_dir" 2>&2; then
            log_error "Failed to clone repository"
            return $EXIT_GIT_FAILED
        fi
    fi

    log_info "Repository ready at: $target_dir"
}

# Create and checkout a new branch
# Arguments: repo_dir, branch_name
git_create_branch() {
    local repo_dir="$1"
    local branch_name="$2"

    log_info "Creating branch: $branch_name"

    if ! git -C "$repo_dir" checkout -b "$branch_name" 2>&2; then
        log_error "Failed to create branch: $branch_name"
        return $EXIT_GIT_FAILED
    fi

    log_info "Checked out branch: $branch_name"
}

# Get the current branch name
git_current_branch() {
    local repo_dir="$1"

    git -C "$repo_dir" rev-parse --abbrev-ref HEAD
}

# Check if we're in a git repository
git_is_repo() {
    local dir="$1"

    git -C "$dir" rev-parse --git-dir >/dev/null 2>&1
}
