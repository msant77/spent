# spent

Per-folder time logger CLI. Append-only CSV log per month.

## Stack
- Bash 3.2 compatible (macOS default `/bin/bash`)
- macOS-only (uses BSD `date -j` and `date -v`); no GNU coreutils

## Constraints
- Single-file CLI — no runtime dependencies
- Bash builtins + `date`/`sed`/`awk` only; no python/perl
- Tests are bats; lint is shellcheck

## Files
- `spent` — main script
- `install.sh` — symlinks to `~/.local/bin/spent`
- `tests/test_spent.bats` — full suite

## Workspace rules

Per `~/w/CLAUDE.md` and `~/.claude/projects/-Users-marcosantana-w/memory/MEMORY.md`:
- Every change starts with a GitHub issue
- Commits use Conventional Commits with `(#N)` issue ref
- Final issue comment lists all commits + adds `ready for testing` label
- Marco closes issues; do not run `gh issue close`
