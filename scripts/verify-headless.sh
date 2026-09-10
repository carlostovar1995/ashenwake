#!/usr/bin/env bash
# Headless checks Cloud Agents (and you) should run after editing the Godot project.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

export PATH="${HOME}/.local/bin:/usr/local/bin:${PATH}"

run_godot() {
  local label="$1"
  shift
  local output
  local status
  local script_error_re='SCRIPT ERROR:|ERROR: Failed to load script|ERROR: Failed to (create|instantiate) an autoload'

  echo "==> ${label}"
  set +e
  output="$(godot "$@" 2>&1)"
  status=$?
  set -e
  printf '%s\n' "${output}"
  if (( status != 0 )); then
    echo "${label} failed (Godot exit code ${status})." >&2
    exit "${status}"
  fi
  if [[ "${output}" =~ ${script_error_re} ]]; then
    echo "${label} reported a script or autoload error." >&2
    exit 1
  fi
}

if ! command -v godot >/dev/null 2>&1; then
  echo "godot not found. Run ./scripts/cloud-agent-install.sh first." >&2
  exit 1
fi

if [[ ! -f "${ROOT}/project.godot" ]]; then
  echo "No project.godot in ${ROOT}" >&2
  exit 1
fi

if [[ ! -f "${ROOT}/.godot-version" ]]; then
  echo "Missing ${ROOT}/.godot-version" >&2
  exit 1
fi

pin="$(tr -d '\r\n[:space:]' < "${ROOT}/.godot-version")"
if [[ ! "${pin}" =~ ^([0-9]+\.[0-9]+\.[0-9]+)-([[:alnum:]]+)$ ]]; then
  echo "Invalid .godot-version '${pin}'. Expected an exact pin such as 4.7.2-stable." >&2
  exit 1
fi
pin_version="${BASH_REMATCH[1]}"
pin_channel="${BASH_REMATCH[2],,}"

installed="$(godot --version 2>&1)"
if [[ ! "${installed}" =~ ([0-9]+\.[0-9]+\.[0-9]+)[.-](stable|rc|beta|alpha|dev) ]]; then
  echo "Could not parse Godot version output: '${installed}'" >&2
  exit 1
fi
installed_version="${BASH_REMATCH[1]}"
installed_channel="${BASH_REMATCH[2],,}"
if [[ "${installed_version}" != "${pin_version}" || "${installed_channel}" != "${pin_channel}" ]]; then
  echo "Godot version mismatch. Repo requires ${pin}; installed godot reports '${installed}'." >&2
  exit 1
fi

echo "Godot ${installed} matches ${pin}"

run_godot "Import" --headless --path "${ROOT}" --import
run_godot "Project script check" --headless --path "${ROOT}" --editor --quit
run_godot "Run check script" --headless --path "${ROOT}" --script res://tools/ci_check.gd
run_godot "Spawn smoke test" --headless --path "${ROOT}" --script res://tools/smoke_test.gd

echo "Headless verify passed."
