# Claude Code Context

Shell scripts for n8n to orchestrate Claude Code sessions remotely.

## Architecture

- `bin/` - Executable entry points called by n8n
- `lib/` - Shared shell libraries (source these, don't execute directly)
- `config/prompts/` - System prompts appended to Claude sessions

## Key Design Decisions

1. **JSON to stdout, logs to stderr** - n8n parses stdout as JSON
2. **Text-only questions** - Claude uses `AWAITING_USER_INPUT: true` marker instead of AskUserQuestion tool
3. **Session persistence** - Uses `--session-id` for new sessions, `--resume` for continuations
4. **Branch naming** - `benji/YYYYMMDD-HHMMSS-{uuid8}` format

## Adding New Scripts

1. Create entry point in `bin/`
2. Source libraries: `source "${LIB_DIR}/common.sh"` etc.
3. Use `parse_args` for argument handling
4. Use `output_success` / `output_error` for JSON output
5. Create corresponding prompt in `config/prompts/`

## Testing

```bash
# Test validation
./bin/benji-init.sh  # Should error with missing params

# Test with mock (won't actually clone/run claude)
DEBUG=true ./bin/benji-init.sh "git@github.com:test/repo.git" \
  "550e8400-e29b-41d4-a716-446655440000" false /tmp
```

## Exit Codes

- 0: Success
- 1: Invalid parameters
- 2: Git operation failed
- 3: Claude execution failed
- 4: File/directory not found
