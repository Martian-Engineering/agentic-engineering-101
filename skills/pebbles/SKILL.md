---
name: pebbles
description: "Issue tracking and workflow with pebbles (pb). Use when managing tasks, epics, dependencies, planning work, or prioritizing issues."
user-invocable: false
---

# Pebbles — Issue Tracking & Workflow

Pebbles (`pb`) is a minimal, git-native issue tracker with an append-only event log. Issues live in `.pebbles/` in your repo. No daemon, no server — just a CLI and a SQLite cache.

## Quick Reference

```bash
pb help                              # Full CLI documentation
pb list                              # List open/in_progress issues (default)
pb list --all                        # Include closed issues
pb list --status closed              # Filter by specific status
pb ready                             # Issues with no open blockers
pb show <id>                         # Full issue details
pb create --title="..." --type=task  # Create an issue
pb update <id> --status in_progress  # Update status
pb update <id> --title "New title"   # Update title
pb close <id>                        # Close an issue
pb comment <id> --body "..."         # Add a comment
pb dep add <A> <B>                   # A depends on B (B blocks A)
pb dep tree <id>                     # Visualize dependency tree
pb sync                              # Commit pebbles events to git
pb log                               # Show the event log
```

**Environment:** Set `PEBBLES_DIR` to override the default `.pebbles` directory. Useful in worktrees where you want to reference the main repo's pebbles data.

## Issue Fields

- **Status**: `open`, `in_progress`, `closed`
- **Type**: Free-form. Common: `task`, `bug`, `feature`, `epic`
- **Priority**: P0 (critical) through P4 (backlog). Default: P2.

## Task Workflow

1. **Find work**: `pb ready` to see actionable issues
2. **Claim it**: `pb update <id> --status in_progress`
3. **Do the work**: Implement the fix/feature
4. **Close it**: `pb close <id>`
5. **Commit**: Reference the issue ID in your commit message
6. **Push**: `git push` (pebbles state is tracked by git)

## Plan Mode Workflow

When working on complex features that require planning:

1. **During planning**: Explore the codebase, understand patterns, write a detailed plan
2. **Create issues from the plan**: Always create pebbles issues before writing code
   - Create an **epic** for the overall feature
   - Create **subtasks** as individual issues, one per discrete piece of work
   - Each issue description should capture context from the plan
3. **Set up hierarchy and dependencies**:
   - Use `pb update <subtask-id> --parent=<epic-id>` for structural relationships
   - Use `pb dep add <task-a> <task-b>` for execution order (A waits for B)
4. **Implement**: Work through subtasks using the task workflow above

**Key distinction:**
- `--parent`: Structural ("this task belongs to this epic")
- `pb dep add`: Execution order ("this task must wait for that task")

## Epics & Dependencies

Epics are issues of type `epic` that group related work. Their children are individual tasks.

**Dependency direction:** `pb dep add A B` means "A depends on B" (B blocks A).

```bash
# Create an epic and its subtasks
pb create --title="User Auth" --type=epic --description="..."
pb create --title="Add OAuth2 endpoint" --type=task --description="..."
pb create --title="Add session management" --type=task --description="..."

# Set parent relationships
pb update <task1-id> --parent=<epic-id>
pb update <task2-id> --parent=<epic-id>

# Set execution order (session mgmt needs OAuth2 first)
pb dep add <task2-id> <task1-id>
```

**Correct pattern for epic dependencies:**
```bash
# ✅ Epic depends on its subtasks (epic blocked until subtasks done)
pb dep add <epic-id> <subtask-id>

# ❌ Don't make subtasks depend on the epic (they'll never show in pb ready)
```

## Committing Pebbles Data

**Always commit `.pebbles/events.jsonl`** as part of your workflow. This is the source of truth.

```bash
pb sync          # Stages and commits pebbles events
# or manually:
git add .pebbles/
git commit -m "pb: create issues for auth epic"
```

Commit pebbles changes:
- After creating new issues
- After closing issues
- After status updates
- As part of your feature commits
