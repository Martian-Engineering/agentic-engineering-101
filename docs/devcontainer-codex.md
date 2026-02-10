# Devcontainer + Codex (Option A: postCreate install)

This repo provides a small overlay you can install into any target repository to:

- create/update `.devcontainer/` so VS Code Dev Containers can run,
- install `@openai/codex` inside the container on first create,
- configure Codex instructions by copying `SYSTEM-template.md` to `~/.codex/AGENTS.md` inside the container,
- copy `skills/*` into `~/.codex/skills/` inside the container.

## Install Into A Target Repo

From this repo:

```bash
scripts/devcontainer/install_overlay.sh /path/to/your/repo
```

If files already exist and you want to overwrite (with backups created):

```bash
scripts/devcontainer/install_overlay.sh --force /path/to/your/repo
```

## Try It With martian-todos

This helper clones `Martian-Engineering/martian-todos` into `~/Projects/` and installs the overlay:

```bash
scripts/devcontainer/try_martian_todos.sh
```

Then open the cloned repo in VS Code and run:

- `Dev Containers: Reopen in Container`

