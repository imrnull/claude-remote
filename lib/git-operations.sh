#!/usr/bin/env bash
# git-operations.sh - Git clone and branch operations

set -euo pipefail

# Source common utilities if not already loaded
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
[[ -z "${EXIT_GIT_FAILED:-}" ]] && source "${SCRIPT_DIR}/common.sh"

# Generate feature branch name
# Format: feature/BRANCH_NAME
generate_feature_branch_name() {
    local branch_name="$1"
    echo "feature/${branch_name}"
}

# Clone a repository
# Arguments: repo_url, target_dir
git_clone_repo() {
    local repo_url="$1"
    local target_dir="$2"

    log_info "Cloning repository: $repo_url"
    log_debug "Target directory: $target_dir"

    if ! git clone "$repo_url" "$target_dir" 2>&2; then
        log_debug "Failed to clone repository"
        return $EXIT_GIT_FAILED
    fi

    log_info "Repository cloned to: $target_dir"
}

# Checkout an existing branch
# Arguments: repo_dir, branch_name
git_checkout_branch() {
    local repo_dir="$1"
    local branch_name="$2"

    log_info "Checking out branch: $branch_name"

    if ! git -C "$repo_dir" checkout "$branch_name" 2>&2; then
        log_debug "Failed to checkout branch: $branch_name"
        return $EXIT_GIT_FAILED
    fi
}

# Create and checkout a new branch
# Arguments: repo_dir, branch_name
git_create_branch() {
    local repo_dir="$1"
    local branch_name="$2"

    log_info "Creating branch: $branch_name"

    if ! git -C "$repo_dir" checkout -b "$branch_name" 2>&2; then
        log_debug "Failed to create branch: $branch_name"
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

# Pull latest changes on current branch
git_pull() {
    local repo_dir="$1"

    log_info "Pulling latest changes"

    if ! git -C "$repo_dir" pull 2>&2; then
        log_debug "Pull failed, continuing with existing state"
    fi
}
