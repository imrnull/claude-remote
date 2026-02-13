#!/usr/bin/env bash
# git-operations.sh - Git worktree and branch operations

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

# Create a git worktree from the main repository
# Arguments: main_repo_dir, worktree_dir, feature_branch_name, source_branch
git_create_worktree() {
    local main_repo_dir="$1"
    local worktree_dir="$2"
    local feature_branch_name="$3"
    local source_branch="$4"

    log_info "Creating worktree: $worktree_dir"
    log_debug "Main repo: $main_repo_dir"
    log_debug "Feature branch: $feature_branch_name from $source_branch"

    # Prune stale worktree entries
    git -C "$main_repo_dir" worktree prune 2>&2

    # Fetch latest source branch
    if ! git -C "$main_repo_dir" fetch origin "$source_branch" 2>&2; then
        log_debug "Warning: could not fetch origin/$source_branch, proceeding with local state"
    fi

    # Ensure parent directory exists
    local parent_dir
    parent_dir="$(dirname "$worktree_dir")"
    if [[ ! -d "$parent_dir" ]]; then
        log_info "Creating agents directory: $parent_dir"
        mkdir -p "$parent_dir"
    fi

    # Create worktree with new branch from source
    if ! git -C "$main_repo_dir" worktree add "$worktree_dir" -b "$feature_branch_name" "origin/${source_branch}" 2>&2; then
        log_debug "Failed to create worktree"
        return $EXIT_GIT_FAILED
    fi

    log_info "Worktree created at: $worktree_dir (branch: $feature_branch_name)"
}

# Remove a git worktree
# Arguments: main_repo_dir, worktree_dir
git_remove_worktree() {
    local main_repo_dir="$1"
    local worktree_dir="$2"

    log_info "Removing worktree: $worktree_dir"

    if ! git -C "$main_repo_dir" worktree remove "$worktree_dir" --force 2>&2; then
        log_debug "Failed to remove worktree"
        return $EXIT_GIT_FAILED
    fi
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
