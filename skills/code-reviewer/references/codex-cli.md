# Codex CLI Quick Reference (for Code Reviewer skill)

Only the commands relevant to the code-reviewer skill. For full docs, see `codex --help`.

## codex exec (primary command)

Run a non-interactive task. This is how the reviewer receives and processes review prompts.

```bash
codex exec "<prompt>" [options]
# Or use command substitution for file-based prompts:
codex exec "$(cat /tmp/prompt.md)" [options]
```

> `codex exec` automatically runs with `approval: never` — do NOT pass `--ask-for-approval` or `-a`, they are not accepted by the exec subcommand and will error.

### Key flags

| Flag | Description |
|------|-------------|
| `--sandbox read-only` | Reviewer can read files but not write. Default for reviews. |
| `-C <path>` | Set workspace root. The reviewer sees files relative to this. |
| `-m <model>` | Override model (e.g., `o3`, `gpt-4.1`). Omit to use config default. |
| `-o <path>` | Write the reviewer's final message to a file. Long form: `--output-last-message`. |
| `--skip-git-repo-check` | Allow running outside a git repo. |
| `--json` | Output newline-delimited JSON events instead of text. |
| `--search` | Enable live web search during review. |

### Example: start a review

```bash
# Write prompt to file
cat > /tmp/review-prompt.md << 'EOF'
Review the error handling in src/services/ for edge cases.
List findings as CRITICAL / WARNING / SUGGESTION with file paths and line numbers.
EOF

# Run review (command substitution reads the file into the prompt arg)
codex exec "$(cat /tmp/review-prompt.md)" \
  --sandbox read-only \
  -C "/path/to/project" \
  -o /tmp/review-output.md
```

## codex exec resume (follow-up)

Continue a previous session. Preserves full conversation context.

```bash
codex exec resume --last "<follow-up prompt>" [options]
```

### Key flags

| Flag | Description |
|------|-------------|
| `--last` | Resume the most recent session from the current working directory. |
| `--all` | Include sessions from any directory when selecting. |
| `-o <path>` | Capture the follow-up response. |

### Example: follow up on a review

```bash
# resume inherits --sandbox, -C, etc. from the original session — only pass --last, prompt, and -o
codex exec resume --last "Elaborate on finding #2. What specific inputs would trigger that null pointer?" \
  -o /tmp/review-followup.md
```

## Config overrides

Override any `~/.codex/config.toml` value inline:

```bash
codex exec "<prompt>" -c model="o3" -c 'sandbox_permissions=["disk-full-read-access"]'
```

## Session management notes

- Each `codex exec` call creates a new session with its own context window.
- `codex exec resume --last` appends to the most recent session.
- Sessions persist on disk. You can resume by session ID if needed: `codex exec resume <SESSION_ID>`.
- Context window usage is not directly exposed. Estimate based on conversation length: if the combined prompts and responses exceed ~50,000 words, consider starting fresh.

## Common pitfalls

| Problem | Cause | Fix |
|---------|-------|-----|
| `unexpected argument '--ask-for-approval'` | This flag only works with the base `codex` command, not `exec` | Remove the flag — `exec` defaults to `approval: never` |
| `unexpected argument '-a'` | Same — short form of the same unsupported flag | Remove the flag |
| Exit code 130 | Signal interrupt (TUI rendering / pipe issue) | Retry the review |
| Garbled `--help` output | Terminal TUI rendering | Pipe through cat: `codex exec --help 2>&1 \| cat` |
| Review output not found | Codex exited abnormally before writing `-o` file | Retry; check terminal output as fallback |
