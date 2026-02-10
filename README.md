# Agentic Engineering 101 (Starter Repo)

This repository is a minimal starter kit for configuring coding agents (Codex + Claude Code) for the workflow we demo. It contains:

- A shared system prompt (`SYSTEM.md`)
- A small set of reusable skills (`skills/`)
- A sync script to install/link these into your local agent config (`scripts/sync-agent-config.sh`)
- A minimal Codex MCP configuration snippet (`codex/config.toml`)

The [presentation we gave in the talk can be found here](https://pagedrop.ai/s/WKGd2MHKtxDh).

## Repository Layout

- `SYSTEM.md`
  - The primary system prompt / working agreements for agents.
  - The sync script installs it by symlinking it into agent-specific locations.

- `skills/`
  - Skill packs (each subdirectory is one skill).
  - Current skills:
    - `skills/maniple/SKILL.md`: orchestrating parallel workers via the maniple MCP tools
    - `skills/pebbles/SKILL.md`: issue tracking workflow with Pebbles (`pb`)

- `scripts/sync-agent-config.sh`
  - Installs this repo's prompt and skills into your local agent config dirs.
  - Safe by default: it creates timestamped backups when it needs to replace files.

- `codex/config.toml`
  - A minimal example snippet for configuring Codex to use the maniple MCP server.
  - The sync script can optionally install/update this into `~/.codex/config.toml`.

## Sync Script

### What It Does

By default, `scripts/sync-agent-config.sh`:

- Symlinks `SYSTEM.md` to:
  - `~/.codex/AGENTS.md`
  - `~/.claude/CLAUDE.md`
- Copies `skills/` into:
  - `~/.codex/skills/`
  - `~/.claude/skills/`

Optionally (with `--codex-config`), it ensures `~/.codex/config.toml` includes the snippet in `codex/config.toml` using a managed block:

- If `~/.codex/config.toml` does not exist, it creates it.
- If it already contains the managed block, it updates that block in-place.
- If it already contains `[mcp_servers.maniple]` (outside the managed block), it leaves the file alone.

### Safety / Backups

- When replacing a file (symlink targets, or `~/.codex/config.toml` during updates), it moves the existing file aside to a timestamped backup like:
  - `~/.codex/AGENTS.md.bak.20260210-123456`
- Skills are copied into destination directories without deleting anything there.

### Usage

```bash
# Show actions without modifying anything
scripts/sync-agent-config.sh --dry-run

# Sync prompt + skills
scripts/sync-agent-config.sh

# Sync prompt + skills, and also install/update Codex MCP snippet
scripts/sync-agent-config.sh --codex-config
```

## Contents (High Level)

- `SYSTEM.md`:
  - General programming rules (small, additive changes; avoid unrequested refactors)
  - Sysadmin rules (make changes reversible; show terminal commands/results)
  - Development workflow guidance (coordinator vs implementer; investigation -> plan -> implement)
  - Git best practices (avoid working on `main` directly; use worktrees where appropriate)

- `skills/maniple/SKILL.md`:
  - How to spawn/monitor/close worker sessions
  - Worktree lifecycle expectations (review and cherry-pick worker commits)

- `skills/pebbles/SKILL.md`:
  - `pb` workflow quick reference (`pb ready`, `pb create`, `pb dep add`, `pb sync`, etc.)
  - Guidance for epics, subtasks, and dependency direction

