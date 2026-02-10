#!/usr/bin/env bash
set -euo pipefail

CODEX_VERSION="${CODEX_VERSION:-0.98.0}"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AGENTS_SRC="${AGENTS_SRC:-$REPO_ROOT/.devcontainer/codex/SYSTEM-template.md}"
SKILLS_SRC_DIR="${SKILLS_SRC_DIR:-$REPO_ROOT/.devcontainer/codex/skills}"

CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
AGENTS_DST="$CODEX_HOME/AGENTS.md"
SKILLS_DST_DIR="$CODEX_HOME/skills"

ts() { date +"%Y%m%d-%H%M%S"; }

backup_path() {
  local path="$1"
  if [[ -e "$path" || -L "$path" ]]; then
    mv "$path" "${path}.bak-$(ts)"
  fi
}

ensure_codex_installed() {
  if ! command -v npm >/dev/null 2>&1; then
    echo "error: npm not found; devcontainer should install Node via features." >&2
    exit 1
  fi

  if command -v codex >/dev/null 2>&1; then
    if codex --version 2>/dev/null | grep -q "codex-cli ${CODEX_VERSION}"; then
      return 0
    fi
  fi

  echo "Installing @openai/codex@${CODEX_VERSION}..."
  sudo npm install -g "@openai/codex@${CODEX_VERSION}"
}

install_agents_md() {
  if [[ ! -f "$AGENTS_SRC" ]]; then
    echo "error: expected AGENTS source at: $AGENTS_SRC" >&2
    echo "hint: the installer script should copy SYSTEM-template.md into .devcontainer/codex/ in the target repo." >&2
    exit 1
  fi

  mkdir -p "$CODEX_HOME"

  if [[ -f "$AGENTS_DST" ]] && cmp -s "$AGENTS_SRC" "$AGENTS_DST"; then
    return 0
  fi

  backup_path "$AGENTS_DST"
  cp "$AGENTS_SRC" "$AGENTS_DST"
}

install_skills() {
  if [[ ! -d "$SKILLS_SRC_DIR" ]]; then
    echo "error: expected skills directory at: $SKILLS_SRC_DIR" >&2
    echo "hint: the installer script should copy skills/* into .devcontainer/codex/skills/ in the target repo." >&2
    exit 1
  fi

  mkdir -p "$SKILLS_DST_DIR"

  local src skill_name dst tmpdir
  for src in "$SKILLS_SRC_DIR"/*; do
    [[ -d "$src" ]] || continue
    skill_name="$(basename "$src")"
    dst="$SKILLS_DST_DIR/$skill_name"

    if [[ -f "$src/SKILL.md" && -f "$dst/SKILL.md" ]] && cmp -s "$src/SKILL.md" "$dst/SKILL.md"; then
      continue
    fi

    if [[ -e "$dst" || -L "$dst" ]]; then
      backup_path "$dst"
    fi

    tmpdir="$(mktemp -d)"
    cp -R "$src" "$tmpdir/$skill_name"
    mv "$tmpdir/$skill_name" "$dst"
    rmdir "$tmpdir"
  done
}

main() {
  ensure_codex_installed
  install_agents_md
  install_skills

  echo "Codex bootstrap complete."
  echo "  Codex: $(command -v codex || true)"
  echo "  AGENTS: $AGENTS_DST"
  echo "  Skills: $SKILLS_DST_DIR"
}

main "$@"
