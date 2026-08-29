#!/usr/bin/env bash
# SemVer helpers for Boss Fighter.
# VERSION file is MAJOR.MINOR.PATCH (no v). Git tags are vMAJOR.MINOR.PATCH.
set -euo pipefail

version_root() {
  local here
  here="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  echo "$here"
}

read_version() {
  local f
  f="$(version_root)/VERSION"
  if [[ -f "$f" ]]; then
    tr -d '[:space:]' < "$f"
  else
    echo "0.1.0"
  fi
}

bump_patch() {
  local ver major minor patch
  ver="$(read_version)"
  IFS=. read -r major minor patch <<< "$ver"
  : "${major:=0}" "${minor:=1}" "${patch:=0}"
  echo "${major}.${minor}.$((patch + 1))"
}

write_version() {
  local ver="$1"
  local root godot
  root="$(version_root)"
  printf '%s\n' "$ver" > "${root}/VERSION"
  godot="${root}/project.godot"
  if [[ -f "$godot" ]]; then
    if grep -q '^config/version=' "$godot"; then
      sed -i "s/^config\\/version=.*/config\\/version=\"${ver}\"/" "$godot"
    else
      sed -i "/^config\\/description=/a config/version=\"${ver}\"" "$godot"
    fi
  fi
}

tag_exists() {
  git -C "$(version_root)" rev-parse -q --verify "refs/tags/v$1" >/dev/null 2>&1
}

create_tag() {
  local ver="$1"
  local msg="${2:-v${ver}}"
  if tag_exists "$ver"; then
    echo "Tag v${ver} already exists."
    return 0
  fi
  git -C "$(version_root)" tag -a "v${ver}" -m "$msg"
  echo "Created tag v${ver}"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  cmd="${1:-current}"
  case "$cmd" in
    current) read_version ;;
    bump-patch)
      ver="$(bump_patch)"
      write_version "$ver"
      echo "$ver"
      ;;
    tag)
      ver="$(read_version)"
      create_tag "$ver" "${2:-v${ver}}"
      ;;
    *)
      echo "Usage: $0 [current|bump-patch|tag]" >&2
      exit 2
      ;;
  esac
fi
