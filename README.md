# my-skills

Public collection of skills built by Mustafa Wahba for personal use and shared publicly for anyone who finds them useful.

These skills are designed to be portable across agent environments such as Claude, Codex, Cursor, Antigravity, OpenClaw, and similar tools. When a skill depends on a specific tool or runtime, that requirement is documented in the skill itself.

## What this repository contains

This repository contains reusable agent skills, plus any supporting references and helper scripts they need.

Current structure:

- `skills/`: skill folders
- each skill may include `references/` for focused docs
- each skill may include `scripts/` for helper automation

The skills in this repository are built using Anthropic's `skill-creator` skill as the authoring workflow.

## Available skills

### `code-reviewer`

Delegates code review work to an independent reviewer so the current agent can get a second opinion on code quality, correctness, edge cases, requirements coverage, and similar review tasks.

Typical requests include:

- review recent changes
- check whether an implementation matches a spec or plan
- look for bugs, regressions, or missed edge cases
- do a security-focused review
- validate architecture or design choices
- inspect or change the reviewer model/reasoning configuration

Current status:

- supports Codex CLI today for running reviews
- Claude Code support is intended to be added soon

Configuration:

- configuration is handled by asking the agent to inspect or update the reviewer settings
- the agent can read or change the active Codex model and reasoning level before running a review
- the reviewer uses the values configured in `~/.codex/config.toml`, including `model` and `model_reasoning_effort`

## Notes

This repo is intentionally small and practical. It is expected to grow over time as more repeatable workflows are turned into shareable skills.
