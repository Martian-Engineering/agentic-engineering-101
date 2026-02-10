#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  scripts/devcontainer/install_overlay.sh [--force] <target-repo-path>

What it does:
  - Installs a .devcontainer/ overlay into the target repo
  - Copies this repo's SYSTEM-template.md to <target>/.devcontainer/codex/SYSTEM-template.md
  - Copies this repo's skills/* to <target>/.devcontainer/codex/skills/

Options:
  --force   If files already exist in the target repo, back them up and overwrite.
EOF
}

die() {
  echo "error: $*" >&2
  exit 1
}

ts() { date +"%Y%m%d-%H%M%S"; }

backup_path() {
  local path="$1"
  if [[ -e "$path" || -L "$path" ]]; then
    mv "$path" "${path}.bak-$(ts)"
  fi
}

copy_file() {
  local src="$1"
  local dst="$2"
  local force="$3"

  [[ -f "$src" ]] || die "missing source file: $src"
  mkdir -p "$(dirname "$dst")"

  if [[ -e "$dst" || -L "$dst" ]]; then
    if [[ "$force" != "1" ]]; then
      die "destination exists (use --force): $dst"
    fi
    backup_path "$dst"
  fi

  cp "$src" "$dst"
}

copy_dir() {
  local src="$1"
  local dst="$2"
  local force="$3"

  [[ -d "$src" ]] || die "missing source dir: $src"
  mkdir -p "$(dirname "$dst")"

  if [[ -e "$dst" || -L "$dst" ]]; then
    if [[ "$force" != "1" ]]; then
      die "destination exists (use --force): $dst"
    fi
    backup_path "$dst"
  fi

  cp -R "$src" "$dst"
}

main() {
  local force="0"
  if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    usage
    exit 0
  fi
  if [[ "${1:-}" == "--force" ]]; then
    force="1"
    shift
  fi

  local target_repo="${1:-}"
  [[ -n "$target_repo" ]] || { usage; exit 1; }
  [[ -d "$target_repo" ]] || die "target repo path does not exist: $target_repo"

  local script_dir repo_root template_devcontainer template_agents template_skills
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  repo_root="$(cd "$script_dir/../.." && pwd)"

  template_devcontainer="$repo_root/templates/devcontainer/.devcontainer"
  template_agents="$repo_root/SYSTEM-template.md"
  template_skills="$repo_root/skills"

  [[ -d "$template_devcontainer" ]] || die "missing template devcontainer dir: $template_devcontainer"
  [[ -f "$template_agents" ]] || die "missing SYSTEM-template.md: $template_agents"
  [[ -d "$template_skills" ]] || die "missing skills dir: $template_skills"

  echo "Installing devcontainer overlay into: $target_repo"

  # 1) Install devcontainer core files.
  copy_file "$template_devcontainer/devcontainer.json" \
    "$target_repo/.devcontainer/devcontainer.json" \
    "$force"
  copy_file "$template_devcontainer/postCreate.sh" \
    "$target_repo/.devcontainer/postCreate.sh" \
    "$force"

  # 2) Install Codex prompt + skills that postCreate.sh consumes.
  copy_file "$template_agents" \
    "$target_repo/.devcontainer/codex/SYSTEM-template.md" \
    "$force"

  mkdir -p "$target_repo/.devcontainer/codex/skills"
  local src skill_name dst
  for src in "$template_skills"/*; do
    [[ -d "$src" ]] || continue
    skill_name="$(basename "$src")"
    dst="$target_repo/.devcontainer/codex/skills/$skill_name"
    copy_dir "$src" "$dst" "$force"
  done

  echo "Done."
  echo "Next: open the target repo in VS Code and run 'Dev Containers: Reopen in Container'."
}

main "$@"

