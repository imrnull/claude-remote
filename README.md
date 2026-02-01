# Claude Remote Scripts

Shell scripts for orchestrating Claude Code sessions remotely via n8n workflows. Clone repositories, create branches, and run Claude Code with persistent sessions.

## Quick Start

```bash
# New session with task description
./bin/benji-init.sh \
  "git@github.com:org/repo.git" \
  "550e8400-e29b-41d4-a716-446655440000" \
  false \
  "/path/to/work/dir" \
  "Add a dark mode toggle to the settings page"

# Continue session with user response
./bin/benji-init.sh \
  "git@github.com:org/repo.git" \
  "550e8400-e29b-41d4-a716-446655440000" \
  true \
  "/path/to/work/dir" \
  "Here are my answers to your questions..."
```

## Arguments

| Position | Name | Required | Description |
|----------|------|----------|-------------|
| $1 | REPO_URL | Yes | SSH git URL (e.g., `git@github.com:org/repo.git`) |
| $2 | CHAT_ID | Yes | UUID - becomes Claude session ID |
| $3 | CONTINUATION | Yes | `true` or `false` |
| $4 | WORK_BASE_DIR | Yes | Base directory for cloning |
| $5 | USER_MESSAGE | Yes | Task description (new) or response (continuation) |

## Output

All scripts output JSON to stdout. Logs go to stderr.

### Success Response

```json
{
  "status": "success",
  "session_id": "550e8400-e29b-41d4-a716-446655440000",
  "repo_path": "/work/repo",
  "branch_name": "benji/20260131-143022-550e8400",
  "claude_response": { ... }
}
```

### Error Response

```json
{
  "status": "error",
  "error_code": 2,
  "error_message": "Failed to clone repository",
  "session_id": "550e8400-e29b-41d4-a716-446655440000",
  "repo_path": "/work/repo",
  "branch_name": null
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

### New Session (CONTINUATION=false)

1. Validate inputs (including USER_MESSAGE as task description)
2. Clone repo to `WORK_BASE_DIR/REPO_NAME`
3. Create branch: `benji/YYYYMMDD-HHMMSS-{first8charsOfUUID}`
4. Run Claude with task description, instructing it to explore and ask questions
5. Output JSON result

### Continuation (CONTINUATION=true)

1. Validate inputs
2. Navigate to existing repo
3. Resume Claude session with user message
4. Output JSON result

## n8n Integration

Claude is instructed to ask questions as plain text ending with:

```
AWAITING_USER_INPUT: true
```

n8n workflows can detect this marker to know when to collect user input before continuing the session.

## Project Structure

```
claude-remote/
├── bin/
│   └── benji-init.sh           # Main entry point
├── lib/
│   ├── common.sh               # Logging, validation, parsing
│   ├── git-operations.sh       # Git clone, branch operations
│   ├── claude-session.sh       # Claude Code invocation
│   └── output.sh               # JSON output formatting
├── config/
│   └── prompts/
│       └── benji-init.txt      # System prompt for Benji
└── .gitignore
```

## Requirements

- Bash 4+
- Git
- Claude Code CLI (`claude`)
- jq (for JSON formatting)

## License

MIT
