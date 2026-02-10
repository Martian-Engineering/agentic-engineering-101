#!/usr/bin/env bash
set -euo pipefail

die() {
  echo "error: $*" >&2
  exit 1
}

usage() {
  cat <<'EOF'
Usage:
  scripts/devcontainer/try_martian_todos.sh [--dir <path>] [--force]

Defaults:
  --dir  ~/Projects/martian-todos

What it does:
  - Clones Martian-Engineering/martian-todos (if missing)
  - Installs this repo's devcontainer overlay into that clone
EOF
}

expand_tilde() {
  local p="$1"
  if [[ "$p" == "~/"* ]]; then
    echo "$HOME/${p:2}"
  else
    echo "$p"
  fi
}

main() {
  local target_dir="~/Projects/martian-todos"
  local force="0"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help) usage; exit 0 ;;
      --dir) target_dir="${2:-}"; shift 2 ;;
      --force) force="1"; shift ;;
      *) die "unknown argument: $1" ;;
    esac
  done

  target_dir="$(expand_tilde "$target_dir")"
  [[ -n "$target_dir" ]] || die "--dir is required"

  if [[ -d "$target_dir/.git" ]]; then
    echo "Repo already exists: $target_dir"
  else
    if [[ -e "$target_dir" ]]; then
      if [[ "$force" != "1" ]]; then
        die "path exists but is not a git repo (use --force): $target_dir"
      fi
      mv "$target_dir" "${target_dir}.bak-$(date +%Y%m%d-%H%M%S)"
    fi

    mkdir -p "$(dirname "$target_dir")"
    echo "Cloning into: $target_dir"
    git clone "https://github.com/Martian-Engineering/martian-todos.git" "$target_dir"
  fi

  local script_dir repo_root
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  repo_root="$(cd "$script_dir/../.." && pwd)"

  "$repo_root/scripts/devcontainer/install_overlay.sh" --force "$target_dir"

  cat <<EOF

Next steps:
  1. Open $target_dir in VS Code
  2. Run: Dev Containers: Reopen in Container

EOF
}

main "$@"

