# Claude Remote Scripts

Shell scripts for orchestrating Claude Code sessions remotely via n8n workflows and locally via the CLI. Uses git worktrees for fast, lightweight workspace creation from pre-existing local repositories. Also supports Obsidian vault sessions for non-git workflows.

## Quick Start

### Remote session (n8n)

```bash
# 1. Copy and configure .env
cp .env.example .env
# Edit .env: set ROOT_DIR to your repos directory

# 2. Encode the prompt as base64
PROMPT=$(echo "Add a dark mode toggle to the settings page" | base64)

# 3. New session - worktree doesn't exist, will create from source branch
./bin/remote-claude \
  "550e8400-e29b-41d4-a716-446655440000" \
  "Benji/react-app" \
  "BP25-123" \
  "develop" \
  "$PROMPT"

# 4. Continuation - worktree exists, will resume session
PROMPT=$(echo "Use CSS variables for the theme colors" | base64)
./bin/remote-claude \
  "550e8400-e29b-41d4-a716-446655440000" \
  "Benji/react-app" \
  "BP25-123" \
  "develop" \
  "$PROMPT"
```

### Local interactive session (CLI)

```bash
# Start a new session - creates worktree and launches Claude interactively
./bin/setup-stream "Benji/react-app" "BP25-123" "develop"

# Resume an existing session
./bin/resume-claude "Benji/react-app" "BP25-123"

# Finalize - push, merge, and remove worktree
./bin/close-stream "Benji/react-app" "BP25-123" "main"
```

### Obsidian vault session (n8n)

```bash
PROMPT=$(echo "Summarize my meeting notes from today" | base64)
./bin/obsidian-claude \
  "550e8400-e29b-41d4-a716-446655440000" \
  "Personal" \
  "$PROMPT"
```

## Configuration

Create a `.env` file (see `.env.example`):

```bash
ROOT_DIR=/path/to/repos                # Base directory containing all repositories
DEFAULT_SOURCE_BRANCH=main             # Default branch to create features from
OBSIDIAN_VAULTS_DIR=/path/to/vaults    # Base directory for Obsidian vaults
```

## Entry Points

### `bin/remote-claude` - Remote n8n sessions

Primary orchestrator for Claude Code sessions triggered by n8n. Auto-detects whether to start a new session or resume an existing one based on worktree existence.

| Arg | Name | Required | Default | Description |
|-----|------|----------|---------|-------------|
| $1 | CHAT_ID | Yes | - | UUID for the session |
| $2 | REPO_RELATIVE_PATH | Yes | - | Path relative to ROOT_DIR (e.g., `Benji/react-app`) |
| $3 | BRANCH_NAME | Yes | - | Branch identifier (e.g., `BP25-123`) |
| $4 | SOURCE_BRANCH | No | from `.env` | Branch to create feature branch from |
| $5 | PROMPT | Yes | - | **Base64-encoded** task description or user response |

### `bin/obsidian-claude` - Obsidian vault sessions

Claude Code sessions in Obsidian vaults (non-git directories). Creates chat notes with YAML front-matter in `{vault}/Chats/`.

| Arg | Name | Required | Description |
|-----|------|----------|-------------|
| $1 | CHAT_ID | Yes | UUID for the session |
| $2 | VAULT_NAME | Yes | Obsidian vault name (e.g., `Personal`) |
| $3 | PROMPT | Yes | **Base64-encoded** task description or user response |

### `bin/setup-stream` - Local interactive setup

Creates a worktree and launches an interactive Claude session in the terminal.

| Arg | Name | Required | Default | Description |
|-----|------|----------|---------|-------------|
| $1 | REPO_RELATIVE_PATH | Yes | - | Path relative to ROOT_DIR |
| $2 | BRANCH_NAME | Yes | - | Branch identifier |
| $3 | SOURCE_BRANCH | No | from `.env` | Source branch |

### `bin/resume-claude` - Resume local session

Resumes an existing interactive Claude session by reading the stored chat ID from `.CLAUDE_CHAT_ID`.

| Arg | Name | Required | Description |
|-----|------|----------|-------------|
| $1 | REPO_RELATIVE_PATH | Yes | Path relative to ROOT_DIR |
| $2 | BRANCH_NAME | Yes | Branch identifier |

### `bin/close-stream` - Finalize worktree

Pushes the feature branch, merges it into a target branch, and removes the worktree.

| Arg | Name | Required | Description |
|-----|------|----------|-------------|
| $1 | REPO_RELATIVE_PATH | Yes | Path relative to ROOT_DIR |
| $2 | BRANCH_NAME | Yes | Branch identifier |
| $3 | TARGET_BRANCH | Yes | Merge destination (e.g., `main`) |

### `bin/refresh-token` - Refresh credentials

Retrieves Claude Code credentials from the macOS Keychain and writes them to `~/.claude/.credentials.json`. No arguments.

## Path Convention

From `REPO_RELATIVE_PATH = "Benji/react-app"` and `BRANCH_NAME = "BP25-123"`:

- **Main repo:** `ROOT_DIR/Benji/react-app` (must already exist)
- **Worktree:** `ROOT_DIR/Benji/agents/react-app/BP25-123`
- **Feature branch:** `feature/BP25-123`
- **Commit prefix:** `"BP25-123 - "` (auto-derived)

## Output

All n8n-facing scripts output JSON to stdout. Debug logs go to stderr only when `DEBUG=true`.

### Success Response

```json
{
  "status": "success",
  "chat_id": "550e8400-e29b-41d4-a716-446655440000",
  "branch_name": "feature/BP25-123",
  "working_dir": "/path/to/repos/Benji/agents/react-app/BP25-123",
  "awaiting_user_input": true,
  "claude_response": { ... }
}
```

### Error Response

```json
{
  "status": "error",
  "error_code": 2,
  "error_message": "Failed to create worktree",
  "chat_id": "550e8400-e29b-41d4-a716-446655440000",
  "branch_name": "feature/BP25-123",
  "working_dir": "/path/to/repos/Benji/agents/react-app/BP25-123"
}
```

## Exit Codes

| Code | Description |
|------|-------------|
| 0 | Success |
| 1 | Invalid parameters |
| 2 | Git operation failed |
| 3 | Claude execution failed |
| 4 | File/directory not found |

## Flow

### Remote: New Session (worktree doesn't exist)

1. Load `.env` configuration
2. Validate inputs and derive paths
3. Create git worktree at `ROOT_DIR/{org}/agents/{repo}/{branch}`
4. Create feature branch: `feature/BRANCH_NAME` from source branch
5. Save chat ID to `.CLAUDE_CHAT_ID` in worktree
6. Run Claude with task description + system prompt
7. Output JSON result with `awaiting_user_input` flag

### Remote: Continuation (worktree exists)

1. Load `.env` configuration
2. Validate inputs, verify worktree is a git repository
3. Resume Claude session with user message
4. Output JSON result with `awaiting_user_input` flag

### Local: Interactive Session

1. `setup-stream` creates worktree, generates session ID, launches interactive Claude
2. User works with Claude directly in the terminal
3. `resume-claude` re-enters an existing session
4. `close-stream` pushes, merges, and cleans up the worktree

## n8n Integration

The `awaiting_user_input` field in the JSON response indicates whether Claude is waiting for user input. n8n workflows can use this flag to determine when to collect user input before continuing the session.

Claude is instructed to end responses with `AWAITING_USER_INPUT: true` when asking questions, which is automatically parsed into the JSON response.

## Project Structure

```
claude-remote/
├── bin/
│   ├── remote-claude              # n8n: main orchestrator for git-based sessions
│   ├── obsidian-claude            # n8n: Obsidian vault sessions
│   ├── setup-stream               # CLI: create worktree + launch interactive session
│   ├── resume-claude              # CLI: resume an existing interactive session
│   ├── close-stream               # CLI/n8n: push, merge, remove worktree
│   └── refresh-token              # Utility: refresh Claude credentials from keychain
├── lib/
│   ├── common.sh                  # Logging, validation, parsing, .env loading
│   ├── git-operations.sh          # Git worktree and branch operations
│   ├── claude-session.sh          # Claude Code invocation and session management
│   ├── output.sh                  # JSON output formatting
│   └── obsidian.sh                # Obsidian vault operations
├── config/
│   └── prompts/
│       ├── main.txt               # System prompt for remote n8n sessions
│       ├── interactive.txt        # System prompt for local interactive sessions
│       └── obsidian.txt           # System prompt for Obsidian sessions
├── .env.example                   # Configuration template
├── .env                           # Local configuration (not committed)
└── CLAUDE.md                      # Claude Code context file
```

## Requirements

- Bash 4+
- Git
- Claude Code CLI (`claude`)
- jq (for JSON formatting)
- macOS Keychain (for `refresh-token` only)

## License

MIT
