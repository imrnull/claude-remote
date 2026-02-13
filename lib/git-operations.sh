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

# Push a branch to remote
# Arguments: repo_dir, branch_name
git_push_branch() {
    local repo_dir="$1"
    local branch_name="$2"

    log_info "Pushing branch: $branch_name"

    if ! git -C "$repo_dir" push origin "$branch_name" 2>&2; then
        log_debug "Failed to push branch: $branch_name"
        return $EXIT_GIT_FAILED
    fi
}

# Merge a source branch into a target branch (from main repo, not worktree)
# Arguments: main_repo_dir, source_branch, target_branch
git_merge_branch() {
    local main_repo_dir="$1"
    local source_branch="$2"
    local target_branch="$3"

    log_info "Merging $source_branch into $target_branch"

    # Fetch latest
    if ! git -C "$main_repo_dir" fetch origin "$target_branch" 2>&2; then
        log_debug "Failed to fetch $target_branch"
        return $EXIT_GIT_FAILED
    fi

    # Update local target branch to match remote (without checkout)
    git -C "$main_repo_dir" fetch origin "$source_branch" 2>&2

    # Use a temporary worktree for the merge to avoid disturbing main repo checkout
    local tmp_merge_dir
    tmp_merge_dir=$(mktemp -d)

    log_debug "Using temp dir for merge: $tmp_merge_dir"

    if ! git -C "$main_repo_dir" worktree add "$tmp_merge_dir" "origin/${target_branch}" --detach 2>&2; then
        log_debug "Failed to create temp worktree for merge"
        rm -rf "$tmp_merge_dir"
        return $EXIT_GIT_FAILED
    fi

    # Checkout target branch in the temp worktree
    if ! git -C "$tmp_merge_dir" checkout -B "$target_branch" "origin/${target_branch}" 2>&2; then
        log_debug "Failed to checkout $target_branch"
        git -C "$main_repo_dir" worktree remove "$tmp_merge_dir" --force 2>/dev/null
        return $EXIT_GIT_FAILED
    fi

    # Merge feature branch
    if ! git -C "$tmp_merge_dir" merge "$source_branch" --no-edit 2>&2; then
        log_debug "Merge conflict or failure"
        git -C "$tmp_merge_dir" merge --abort 2>/dev/null
        git -C "$main_repo_dir" worktree remove "$tmp_merge_dir" --force 2>/dev/null
        return $EXIT_GIT_FAILED
    fi

    # Push merged target branch
    if ! git -C "$tmp_merge_dir" push origin "$target_branch" 2>&2; then
        log_debug "Failed to push merged $target_branch"
        git -C "$main_repo_dir" worktree remove "$tmp_merge_dir" --force 2>/dev/null
        return $EXIT_GIT_FAILED
    fi

    # Clean up temp worktree
    git -C "$main_repo_dir" worktree remove "$tmp_merge_dir" --force 2>/dev/null

    log_info "Successfully merged $source_branch into $target_branch"
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
