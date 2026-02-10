#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
sync-agent-config.sh

Ensures:
- SYSTEM.md is symlinked to:
  - ~/.codex/AGENTS.md
  - ~/.claude/CLAUDE.md
- Repo skills/ are copied into:
  - ~/.codex/skills
  - ~/.claude/skills
- Optionally, a Codex MCP server config snippet is installed/updated in:
  - ~/.codex/config.toml

Safety:
- If a target file already exists and isn't the desired symlink, it is moved to a
  timestamped backup alongside the original, then replaced.
- Skills are copied without deleting anything in the destination.
- If Codex config is modified, the original file is moved to a timestamped backup
  alongside the original, then replaced.

Usage:
  scripts/sync-agent-config.sh [--dry-run] [--codex-config]
EOF
}

DRY_RUN=0
SYNC_CODEX_CONFIG=0
for arg in "$@"; do
  case "${arg}" in
    --help|-h)
      usage
      exit 0
      ;;
    --dry-run)
      DRY_RUN=1
      ;;
    --codex-config)
      SYNC_CODEX_CONFIG=1
      ;;
    *)
      echo "error: unexpected argument: ${arg}" >&2
      usage >&2
      exit 2
      ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd -P)"
SYSTEM_SRC="${REPO_ROOT}/SYSTEM.md"
SKILLS_SRC="${REPO_ROOT}/skills"
CODEX_CONFIG_SNIPPET="${REPO_ROOT}/codex/config.toml"

if [[ ! -f "${SYSTEM_SRC}" ]]; then
  echo "error: missing ${SYSTEM_SRC}" >&2
  exit 1
fi
if [[ ! -d "${SKILLS_SRC}" ]]; then
  echo "error: missing ${SKILLS_SRC}/" >&2
  exit 1
fi
if [[ "${SYNC_CODEX_CONFIG}" -eq 1 && ! -f "${CODEX_CONFIG_SNIPPET}" ]]; then
  echo "error: missing ${CODEX_CONFIG_SNIPPET}" >&2
  exit 1
fi

timestamp() {
  date "+%Y%m%d-%H%M%S"
}

abs_path() {
  local path="$1"
  (
    cd "$(dirname "${path}")" >/dev/null 2>&1
    printf "%s/%s" "$(pwd -P)" "$(basename "${path}")"
  )
}

run() {
  if [[ "${DRY_RUN}" -eq 1 ]]; then
    printf "[dry-run] %q" "$1"
    shift || true
    for arg in "$@"; do
      printf " %q" "${arg}"
    done
    printf "\n"
    return 0
  fi
  "$@"
}

ensure_parent_dir() {
  local path="$1"
  run mkdir -p "$(dirname "${path}")"
}

backup_if_needed() {
  local path="$1"
  if [[ ! -e "${path}" && ! -L "${path}" ]]; then
    return 0
  fi

  local bak="${path}.bak.$(timestamp)"
  run mv "${path}" "${bak}"
  if [[ "${DRY_RUN}" -eq 1 ]]; then
    echo "would back up ${path} -> ${bak}"
  else
    echo "backed up ${path} -> ${bak}"
  fi
}

ensure_symlink() {
  local target_path="$1"
  local link_src="$2"

  ensure_parent_dir "${target_path}"

  if [[ -L "${target_path}" ]]; then
    # readlink exists on macOS; returns the stored link value (may be relative).
    local existing
    existing="$(readlink "${target_path}" || true)"
    local existing_abs
    if [[ "${existing}" == /* ]]; then
      existing_abs="$(abs_path "${existing}")"
    else
      existing_abs="$(
        cd "$(dirname "${target_path}")" >/dev/null 2>&1
        abs_path "${existing}"
      )"
    fi
    local link_src_abs
    link_src_abs="$(abs_path "${link_src}")"

    if [[ "${existing_abs}" == "${link_src_abs}" ]]; then
      echo "ok symlink ${target_path} -> ${link_src}"
      return 0
    fi
    backup_if_needed "${target_path}"
  elif [[ -e "${target_path}" ]]; then
    backup_if_needed "${target_path}"
  fi

  run ln -s "${link_src}" "${target_path}"
  if [[ "${DRY_RUN}" -eq 1 ]]; then
    echo "would link ${target_path} -> ${link_src}"
  else
    echo "linked ${target_path} -> ${link_src}"
  fi
}

copy_skills_into() {
  local dest_dir="$1"
  run mkdir -p "${dest_dir}"

  if command -v rsync >/dev/null 2>&1; then
    # Copy without deleting anything in dest_dir.
    run rsync -a "${SKILLS_SRC}/" "${dest_dir}/"
  else
    # Fallback: copy the contents of skills/ into the destination.
    # (No deletion; may overwrite same-named files.)
    run cp -R "${SKILLS_SRC}/." "${dest_dir}/"
  fi
  if [[ "${DRY_RUN}" -eq 1 ]]; then
    echo "would copy skills -> ${dest_dir}/"
  else
    echo "copied skills -> ${dest_dir}/"
  fi
}

sync_codex_config() {
  local dest_path="${HOME}/.codex/config.toml"
  local begin_marker="# BEGIN agentic-engineering-101"
  local end_marker="# END agentic-engineering-101"

  if [[ "${DRY_RUN}" -eq 1 ]]; then
    echo "[dry-run] would update ${dest_path} from ${CODEX_CONFIG_SNIPPET}"
    return 0
  fi

  ensure_parent_dir "${dest_path}"

  local tmp
  tmp="$(mktemp "${TMPDIR:-/tmp}/agentic-engineering-101-codex-config.XXXXXX")"

  if [[ ! -f "${dest_path}" ]]; then
    {
      echo "${begin_marker}"
      echo "# This block is managed by scripts/sync-agent-config.sh in ${REPO_ROOT}"
      cat "${CODEX_CONFIG_SNIPPET}"
      echo "${end_marker}"
    } >"${tmp}"
    run mv "${tmp}" "${dest_path}"
    echo "wrote ${dest_path}"
    return 0
  fi

  if grep -qF "${begin_marker}" "${dest_path}"; then
    # Replace the managed block in-place, leaving everything else untouched.
    awk -v begin="${begin_marker}" -v end="${end_marker}" -v snippet="${CODEX_CONFIG_SNIPPET}" -v root="${REPO_ROOT}" '
      $0 == begin {
        inblock = 1
        print begin
        print "# This block is managed by scripts/sync-agent-config.sh in " root
        while ((getline line < snippet) > 0) print line
        close(snippet)
        print end
        next
      }
      inblock == 1 {
        if ($0 == end) inblock = 0
        next
      }
      { print }
    ' "${dest_path}" >"${tmp}"

    backup_if_needed "${dest_path}"
    run mv "${tmp}" "${dest_path}"
    echo "updated ${dest_path} (managed block)"
    return 0
  fi

  if grep -qF "[mcp_servers.maniple]" "${dest_path}"; then
    echo "skipped ${dest_path}: already contains [mcp_servers.maniple]"
    run rm -f "${tmp}"
    return 0
  fi

  # Append a managed block.
  cat "${dest_path}" >"${tmp}"
  printf "\n%s\n" "${begin_marker}" >>"${tmp}"
  printf "%s\n" "# This block is managed by scripts/sync-agent-config.sh in ${REPO_ROOT}" >>"${tmp}"
  cat "${CODEX_CONFIG_SNIPPET}" >>"${tmp}"
  printf "%s\n" "${end_marker}" >>"${tmp}"

  backup_if_needed "${dest_path}"
  run mv "${tmp}" "${dest_path}"
  echo "updated ${dest_path} (appended managed block)"
}

ensure_symlink "${HOME}/.codex/AGENTS.md" "${SYSTEM_SRC}"
ensure_symlink "${HOME}/.claude/CLAUDE.md" "${SYSTEM_SRC}"

copy_skills_into "${HOME}/.codex/skills"
copy_skills_into "${HOME}/.claude/skills"

if [[ "${SYNC_CODEX_CONFIG}" -eq 1 ]]; then
  sync_codex_config
fi
