#!/usr/bin/env bash
# review.sh — Thin wrapper around codex exec for code reviews.
# Usage:
#   review.sh --workspace <path> --prompt-file <file> --output <file> [--model <model>] [--resume]
#   review.sh --workspace <path> --prompt <text> --output <file> [--model <model>] [--resume]
#
# Defaults: --sandbox read-only, --skip-git-repo-check
# Note: codex exec defaults to approval: never automatically — no flag needed.
#
# Prefer --prompt-file over --prompt for long review prompts to avoid shell quoting issues.

set -euo pipefail

WORKSPACE=""
PROMPT=""
PROMPT_FILE=""
OUTPUT=""
MODEL=""
RESUME=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --workspace)   WORKSPACE="$2";   shift 2 ;;
    --prompt)      PROMPT="$2";      shift 2 ;;
    --prompt-file) PROMPT_FILE="$2"; shift 2 ;;
    --output)      OUTPUT="$2";      shift 2 ;;
    --model)       MODEL="$2";       shift 2 ;;
    --resume)      RESUME=true;      shift   ;;
    *)             echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

if [[ -z "$PROMPT" && -z "$PROMPT_FILE" ]] || [[ -z "$OUTPUT" ]]; then
  echo "Error: (--prompt or --prompt-file) and --output are required." >&2
  echo "Usage: review.sh --workspace <path> --prompt-file <file> --output <file> [--model <model>] [--resume]" >&2
  exit 1
fi

if [[ -n "$PROMPT_FILE" && ! -f "$PROMPT_FILE" ]]; then
  echo "Error: prompt file not found: $PROMPT_FILE" >&2
  exit 1
fi

# Resolve prompt text
if [[ -n "$PROMPT_FILE" ]]; then
  PROMPT_TEXT="$(cat "$PROMPT_FILE")"
else
  PROMPT_TEXT="$PROMPT"
fi

# Build the command
CMD=(codex exec)

if [[ "$RESUME" == true ]]; then
  # resume inherits --sandbox, -C, etc. from original session
  # only accepts --last, prompt, -o, and --image
  CMD=(codex exec resume --last)
  CMD+=("$PROMPT_TEXT")
  CMD+=(-o "$OUTPUT")
else
  CMD+=("$PROMPT_TEXT")
  CMD+=(--sandbox read-only)
  CMD+=(--skip-git-repo-check)
  CMD+=(-o "$OUTPUT")

  if [[ -n "$WORKSPACE" ]]; then
    CMD+=(-C "$WORKSPACE")
  fi

  if [[ -n "$MODEL" ]]; then
    CMD+=(-m "$MODEL")
  fi
fi

exec "${CMD[@]}"
