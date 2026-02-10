---
name: maniple
description: "Agent orchestration with maniple. Use when spawning or managing worker sessions, coordinating parallel work, or using git worktrees for multi-agent workflows."
user-invocable: false
---

# maniple — Agent Orchestration

maniple is an MCP server that lets you spawn and manage teams of coding agent sessions (Claude Code or Codex). Each worker gets their own terminal pane, optional git worktree, and can be assigned pebbles issues.

## Why Use maniple?

- **Parallelism**: Fan out work to multiple agents working simultaneously
- **Context isolation**: Each worker has fresh context, keeps coordinator context clean
- **Visibility**: Real sessions you can watch, interrupt, or take over in the terminal
- **Git worktrees**: Each worker gets an isolated branch for their work

## Prerequisites

- macOS with iTerm2 (Python API enabled) or tmux
- maniple MCP server configured and running

## Roles: Coordinator vs Implementer

**As a coordinator** (the typical role when using maniple):
- Break down work into tightly scoped pebbles issues with dependencies
- Spawn workers for implementation — **do NOT implement code yourself**
- Review worker output before merging
- Your job is planning, delegation, and integration

**As an implementer** (spawned by maniple to do work):
- Execute ONLY the assigned task
- Do NOT spawn additional workers or reorganize project structure
- Do NOT go beyond the scope of your assigned issue
- Commit your work to your branch and report completion
- If blocked, say so clearly — don't improvise a workaround

## Core Tools

All maniple tools are available as MCP tools prefixed with `mcp__maniple__`.

### Spawning Workers

Use `mcp__maniple__spawn_workers` with a `workers` list:

```json
{
  "workers": [{
    "project_path": "/path/to/repo",
    "bead": "pb-123",
    "annotation": "Fix auth bug",
    "skip_permissions": true,
    "worktree": {"branch": "pb-123-fix-auth", "base": "main"}
  }]
}
```

**Worker config fields:**
- `project_path`: Required. Path to the repository.
- `bead`: Pebbles issue ID. Worker will follow the pebbles workflow for this issue.
- `annotation`: Task description (shown on badge, used in branch name).
- `prompt`: Additional instructions. If no bead, this is their full assignment.
- `skip_permissions`: Always set `true` — workers need write access.
- `worktree`: Branch configuration. `branch` is the new branch name, `base` is what to branch from.
- `name`: Optional worker name (auto-assigned from themed sets if omitted).
- `agent_type`: `"claude"` (default) or `"codex"` for Codex workers.

**Layout options** (passed as `layout` parameter):
- `"auto"`: Reuse existing maniple windows (default)
- `"new"`: Create fresh window

### Listing Workers

Use `mcp__maniple__list_workers`. Optionally pass `status_filter` (`"spawning"`, `"ready"`, `"busy"`, `"closed"`) or `project_filter`.

### Messaging Workers

Use `mcp__maniple__message_workers`:

```json
{
  "session_ids": ["WorkerName"],
  "message": "Please also add unit tests"
}
```

### Reading Worker Logs

Use `mcp__maniple__read_worker_logs`:

```json
{
  "session_id": "WorkerName",
  "pages": 2
}
```

### Checking Worker Status

Quick non-blocking poll with `mcp__maniple__check_idle_workers`:

```json
{
  "session_ids": ["Worker1", "Worker2"]
}
```

Blocking wait with `mcp__maniple__wait_idle_workers`:

```json
{
  "session_ids": ["Worker1", "Worker2"],
  "mode": "all",
  "timeout": 600
}
```

### Closing Workers

Use `mcp__maniple__close_workers`:

```json
{
  "session_ids": ["Worker1", "Worker2"]
}
```

After closing, the worktree is removed but the **branch and commits are preserved**. Review and merge before deleting the branch.

### Recovering After Server Restart

If the MCP server restarts, it loses track of running workers:

1. Find orphaned sessions with `mcp__maniple__discover_workers`
2. Re-adopt a discovered session with `mcp__maniple__adopt_worker` (pass `iterm_session_id` or `tmux_pane_id`)

Codex workers cannot be rediscovered after a server restart. Spawn new ones if needed.

## Workflow: Single Issue

1. **Create the pebbles issue first:**
   ```bash
   pb create --title="Add OAuth2 endpoint" --type=task --priority P1
   pb sync
   ```

2. **Spawn a worker** using `mcp__maniple__spawn_workers` with the issue ID as `bead`, `skip_permissions: true`, and the repo path.

3. **Monitor** using `mcp__maniple__check_idle_workers` and `mcp__maniple__read_worker_logs`.

4. **Review, merge, close:**
   - Close the worker with `mcp__maniple__close_workers`
   - Review the worker's branch commits
   - Cherry-pick or merge into the target branch
   - Delete the worker branch: `git branch -D <worker-branch>`

## Workflow: Parallel Fan-Out

1. **Spawn multiple workers** in a single `mcp__maniple__spawn_workers` call with multiple entries in the `workers` list, each with their own `bead` and `annotation`. Use `layout: "new"` for a fresh window.

2. **Wait for all to complete** with `mcp__maniple__wait_idle_workers` using `mode: "all"`.

3. **Review each, merge, close.**

## Worktree Integration

Workers with worktrees get isolated branches. The worktree lifecycle:

1. **Spawn**: Worktree created at `<repo>/.worktrees/<branch-name>/`
2. **Work**: Agent commits to the worktree's branch
3. **Close**: Worktree directory removed, but branch + commits preserved
4. **Merge**: Coordinator reviews and cherry-picks or merges to parent branch
5. **Cleanup**: `git branch -D <worker-branch>` after merging

**Epic worktree pattern:** Epics get their own worktree. Child tasks are incorporated into the epic's worktree via cherry-pick.

## Best Practices

1. **Always assign pebbles issues** — gives workers clear scope and tracks progress
2. **Commit issues before spawning** — worktrees are created from committed state
3. **Use `skip_permissions: true`** — workers need file write access
4. **Don't implement as coordinator** — spawn workers instead
5. **Review before merging** — check worker branches, run tests
6. **Close workers when done** — cleans up worktrees
7. **Cherry-pick over merge** — for incorporating worktree work into parent branches

## Configuration

Default settings live in `~/.maniple/config.json`.

```bash
# Server logs
tail -f ~/.maniple/logs/stdout.log
tail -f ~/.maniple/logs/stderr.log
```
