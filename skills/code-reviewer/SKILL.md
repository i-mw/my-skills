---
name: code-reviewer
description: Delegate code review tasks to Codex CLI as an independent reviewer. Use this skill whenever the user asks for a code review, wants to validate implementation against requirements, needs a second opinion on code changes, wants dry-run testing or edge case analysis, asks to review an implementation plan before or after coding, or mentions anything about reviewing, auditing, or validating code quality. Always use this skill even if the user just casually says "have someone look at this" or "check if this is correct" — those are review requests. Also use this skill when the user asks to check, change, or configure the code reviewer's model or reasoning level.
---

# Code Reviewer

Delegate code review tasks to an independent Codex CLI reviewer. The reviewer runs in a separate process, reads the workspace, and reports findings back. It should not modify files — the calling agent decides what to act on.

This skill is about **orchestrating** the review, not performing it yourself. You build the prompt, send it to Codex, read the findings, iterate if needed, and report back.

## Prerequisites

Codex CLI must be installed and authenticated. Before your first review call, verify this:

```bash
codex --version && codex login status
```

If either fails, tell the user: "Codex CLI is not installed or not authenticated. Please install it from https://github.com/openai/codex and run `codex login` to authenticate before using the code reviewer."

Do not proceed with the review until this is resolved.

**Report model and reasoning level.** Immediately after confirming Codex is installed and authenticated, read the active configuration:

```bash
cat ~/.codex/config.toml
```

Extract the `model` and `model_reasoning_effort` values and report them to the user:

> "The code reviewer will use model **{model}** with reasoning effort **{level}**. If you want to change either before I proceed, interrupt me now."

Do NOT wait for the user to respond — continue building the review prompt. This gives the user a window to interrupt if the defaults are wrong, without blocking the workflow.

## Managing Codex Configuration

These operations can be performed standalone (without a review task) whenever the user asks.

### Reading current model and reasoning level

```bash
cat ~/.codex/config.toml
```

Parse the top-level `model` and `model_reasoning_effort` keys. If a key is absent, Codex uses its built-in default (currently `o4-mini` for model, `high` for reasoning effort). Report both values to the user.

### Changing the model

Edit `~/.codex/config.toml` and replace the `model` value. Use the StrReplace tool (or equivalent file editor) — do not rewrite the entire file.

Example: changing from `gpt-5.4` to `o3`:
```
old: model = "gpt-5.4"
new: model = "o3"
```

If the `model` key doesn't exist, add it as the first line after any existing comments or blank lines at the top of the file.

### Changing the reasoning effort

Edit `~/.codex/config.toml` and replace the `model_reasoning_effort` value. Available levels: `low`, `medium`, `high`, `xhigh`.

Example: changing from `xhigh` to `high`:
```
old: model_reasoning_effort = "xhigh"
new: model_reasoning_effort = "high"
```

If the `model_reasoning_effort` key doesn't exist, add it directly after the `model` line.

### Changing both at once

When the user asks to change both, edit both keys in the same operation.

After any config change, confirm by reading the file back and reporting the new values to the user.

## How It Works

### Step 1: Build the review prompt

A good review prompt is the difference between useful feedback and noise. Include:

- **What to review**: Specific file paths, or "all recent changes in the working directory."
- **Requirements context**: If there's an implementation plan or task description, include it verbatim or summarize the key requirements. The reviewer has no memory of your conversation — it starts from zero.
- **Review type**: What kind of review? (see Review Types below)
- **Specific concerns**: If the user mentioned particular worries, relay them.
- **Expected output format**: Ask the reviewer to structure findings by severity (critical / warning / suggestion) and include file paths + line references.
- **Images**: If the user provides screenshots, mockups, or design specs, attach them with `-i <path>` when running `codex exec`. Useful for UI/frontend reviews where the reviewer needs to compare code output against visual references.

Example prompt structure:
```
You are reviewing code changes in this workspace.

## Requirements
[paste or summarize the implementation plan / task requirements]

## What to review
[list specific files or describe the scope]

## Review focus
[general quality / security / edge cases / against requirements / etc.]

## Output format
Structure your findings as:
- CRITICAL: Issues that will cause bugs or security problems
- WARNING: Issues that should be addressed but won't break things
- SUGGESTION: Improvements for readability, performance, or maintainability

Include file paths and line numbers for each finding.

## Constraints
You are a READ-ONLY reviewer. Do NOT create, modify, or delete any files. Do NOT run commands that have side effects (no installs, no writes, no network calls that mutate state). Only read files and report findings.
```

**Write the prompt to a temp file, not inline.** Review prompts are long. Passing them as CLI arguments causes quoting issues and can hit shell limits. Write the prompt to a temp file first:

```bash
# Write prompt to a temp file
cat > $TEMP/review-prompt.md << 'REVIEW_EOF'
[your full review prompt here]
REVIEW_EOF
```

### Step 2: Run the review

Pass the prompt to `codex exec` inline for short prompts, or pipe it via stdin for long prompts. Use `-` as the prompt argument to read from stdin — this avoids shell argument length limits and quoting issues with large prompts.

**Command patterns** (choose one):

```bash
# Pattern A: Inline prompt (short prompts only)
codex exec "Review lib/utils/foo.js for code quality. List 3 findings max." \
  --sandbox danger-full-access \
  -c 'web_search="live"' \
  --color never \
  -C "<workspace-path>" \
  -o $TEMP/code-review-output.md

# Pattern B: Prompt from file via stdin (recommended for long prompts)
cat $TEMP/review-prompt.md | codex exec - \
  --sandbox danger-full-access \
  -c 'web_search="live"' \
  --color never \
  -C "<workspace-path>" \
  -o $TEMP/code-review-output.md
```

**Key flags:**

| Flag | Purpose |
|------|---------|
| `--sandbox danger-full-access` | Disables sandbox isolation. Required on Windows because `workspace-write` and `read-only` use `CreateProcessWithLogonW` for process isolation, which fails with error 1056 under concurrent/parallel tool calls. The reviewer is prompt-constrained to read-only behavior — the calling agent decides what to act on. |
| `-c 'web_search="live"'` | Enable live web search. Lets the reviewer look up CVEs, deprecated APIs, library docs, and current best practices during the review. Always include this flag. The `--search` global flag is not accepted by `codex exec` — use this config override instead. |
| `--color never` | Prevent ANSI escape codes in the `-o` output file. Ensures clean markdown output. |
| `-C <path>` | Set workspace root so the reviewer sees the right files. |
| `-o <path>` | Write the reviewer's final message to a file. Long form: `--output-last-message`. |
| `-i <path>` | Attach image(s) to the prompt. Use when the user provides screenshots, mockups, or design specs for UI/frontend reviews. Comma-separated for multiple images. |
| `-m <model>` | Override model. Only use when the user explicitly requests a specific model. |
| `-c model_reasoning_effort=<level>` | Override reasoning effort (low/medium/high/xhigh). Only use when the user explicitly requests a specific level. |

`codex exec` runs non-interactively by default — it automatically sets `approval: never`, so no approval flag is needed. Do NOT pass `--ask-for-approval` or `-a` — these flags are not accepted by the `exec` subcommand and will cause an error.

Run this as a **background command**. Thorough reviews can take up to 5 minutes for large codebases.

**Capture the session ID**: When Codex starts, it prints a header that includes `session id: <uuid>`. Read this from the terminal output and save it — you'll need it for resume calls in Steps 4 and 5.

**Monitoring the review**: After launching, wait patiently. Check command status with generous intervals — every 30-60 seconds is enough. Do not poll rapidly. The reviewer needs time to read files, reason, and produce findings.

### Step 3: Read the findings

Once the command completes, **read the output file**. This is where the reviewer's full structured response lives. Do not try to parse the review from terminal stdout — always read the `-o` output file.

**Path resolution**: `$TEMP/code-review-output.md` is a shell variable. To read the file with a non-shell tool (like the Read tool), resolve the actual path first by running `cygpath -w $TEMP/code-review-output.md` (Windows) or `echo $TEMP/code-review-output.md` (Linux/macOS) in the shell. On Windows, `$TEMP` typically resolves to `C:\Users\<user>\AppData\Local\Temp`.

If the output file is missing (Codex exited abnormally), fall back to checking terminal output from the command. Abnormal exits can happen due to signal interrupts — retry the review if this occurs.

Parse the reviewer's findings and evaluate them yourself before presenting to the user. You have context the reviewer doesn't — use your judgment:

- If a finding is correct and actionable, note it.
- If a finding seems wrong (maybe the reviewer misunderstood a pattern or convention), flag it for discussion.
- If a finding is trivial or the reviewer is being overly cautious, you can deprioritize it.

### Step 4: Iterate with the reviewer

If you need to drill deeper, challenge a finding, or ask the reviewer to focus on something specific, resume the session:

```bash
codex exec resume <SESSION_ID> "Can you elaborate on finding #2? What inputs would trigger that edge case?" \
  -o $TEMP/code-review-followup.md
```

For long follow-up prompts, use the same file pattern:

```bash
codex exec resume <SESSION_ID> "$(cat $TEMP/review-followup-prompt.md)" \
  -o $TEMP/code-review-followup.md
```

`resume` inherits `--sandbox`, `-C`, `web_search`, and other settings from the original session — do not pass them again. The only flags `resume` accepts are `-o`, `--image`, and the prompt. Use the session ID captured from the Codex startup header in Step 2.

Resuming by session ID continues the exact session, preserving the reviewer's full context. Use this for:
- "Can you elaborate on finding #3? What specific input would trigger that edge case?"
- "You flagged X as a problem, but it's intentional because of Y. Given that, do you still see issues?"
- "Now focus specifically on error handling in the service layer."
- "Run a mental dry-run of this function with these inputs: [...]"

You can iterate multiple rounds. Each `resume` call adds to the same conversation.

### Step 5: Handle context limits

Codex sessions have finite context. To track usage concretely, add `--json` to any `codex exec` or `codex exec resume` call. The `turn.completed` JSON event reports token counts:

```json
{"type":"turn.completed","usage":{"input_tokens":49541,"cached_input_tokens":46720,"output_tokens":249}}
```

`input_tokens` is the total context consumed so far. Monitor this across rounds:

- **If you're close to finishing** (one or two more questions), keep going in the same session even if context is getting full. Finishing the thought is better than restarting.
- **If significant work remains** (more files to review, more iterations needed), resume the session with a summary prompt that refocuses the reviewer:
  ```bash
  codex exec resume <SESSION_ID> "$(cat $TEMP/review-continuation-prompt.md)" \
    -o $TEMP/code-review-continuation.md
  ```
  In the continuation prompt:
  - Summarize key findings so far.
  - Re-include relevant requirements / implementation plan sections.
  - Specify what still needs review.
  - Do NOT dump the entire previous conversation — give only what the reviewer needs to continue effectively.
  
  This preserves more context than starting from scratch. Only start a truly fresh `codex exec` for a completely new, unrelated review task.

### Step 6: Report back

Summarize the reviewer's findings to the user. Organize by severity. For each finding:
- Explain what the reviewer found.
- State whether you agree or disagree, and why.
- If you agree, offer to implement the fix (or implement it directly if the user has given you leeway).

If the user wants to iterate (e.g., "have the reviewer look at the fixes you just made"), go back to Step 1 with a new or resumed session.

## Review Types

### General code quality
Broad review covering readability, patterns, naming, error handling, code organization. Good default when the user doesn't specify.

### Review against requirements
The reviewer checks whether the implementation satisfies a spec. You provide the requirements/plan and ask the reviewer to verify each requirement is met. Particularly useful after implementing from an implementation plan.

### Security review
Focus on input validation, injection vectors, auth/authz gaps, secret handling, dependency vulnerabilities. Instruct the reviewer to think like an attacker.

### Edge case / dry-run testing
Ask the reviewer to mentally execute code paths with unusual inputs: empty strings, null values, very large numbers, concurrent calls, network failures, etc. Ask for specific inputs that would break the code.

### Architecture / design review
Higher-level review of module structure, dependency flow, separation of concerns, extensibility. Useful before implementation or for major refactors.

## When Things Go Wrong

### The reviewer is stuck or gives unhelpful responses
Iterate once with a more specific prompt. If the response is still poor, try a fresh session with a differently structured prompt. If the reviewer consistently fails on the task, escalate to the user — tell them what you asked, what the reviewer said, and ask how they'd like to proceed.

### The agent (you) is stuck
If you're unsure how to interpret the reviewer's findings, or whether to implement suggested changes, ask the user. Don't silently apply changes you're not confident about. Don't silently discard findings either.

### Codex errors or timeouts
If `codex exec` fails or times out, check the error output. Common issues:
- **`unexpected argument '--ask-for-approval'` or `'-a'`** — Do not use these flags with `codex exec`. The exec subcommand defaults to `approval: never` automatically. No approval flag is needed.
- **`CreateProcessWithLogonW failed: 1056` or similar** — The Windows sandbox can't handle concurrent process creation. This is why the skill uses `--sandbox danger-full-access` instead of `workspace-write`. If you see this error, confirm the `--sandbox danger-full-access` flag is present. If someone changed it back to `workspace-write` or `read-only`, that's the cause. Re-onboarding the sandbox (`experimental_windows_sandbox = false` in config, restart, re-accept prompt) may temporarily fix `workspace-write` mode, but the concurrency issue will recur under parallel tool calls.
- **Exit code 130** — Signal interrupt. Check terminal output for `CreateProcessWithLogonW failed` errors. If present, ensure `--sandbox danger-full-access` is set and retry. If no sandbox errors visible, the review may have been too broad — break it into smaller scopes and retry in parts.
- Not authenticated — tell user to run `codex login`
- Model not available — try without `-m` flag to use default
- Timeout — the review was too broad. Break it into smaller scopes and review in parts.

If the problem persists, tell the user what's happening so they can troubleshoot.

## Model and Reasoning Configuration

By default, the reviewer uses whatever model and reasoning effort are configured in `~/.codex/config.toml`. Do NOT override these unless the user explicitly requests a specific model or reasoning level.

**Model override** — only when the user asks:
```bash
codex exec "..." -m gpt-5.4 ...
```

**Reasoning effort override** — only when the user asks:
```bash
codex exec "..." -c model_reasoning_effort=xhigh ...
```

Available reasoning effort levels: `low`, `medium`, `high`, `xhigh`. The correct config key is `model_reasoning_effort` (not `reasoning_effort`). Verify the header output shows the expected level. Higher levels produce deeper analysis but take longer and cost more. Let the user make that tradeoff — never change these on your own.
