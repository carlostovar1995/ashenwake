#!/usr/bin/env bash
# Headless checks Cloud Agents (and you) should run after editing the Godot project.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

export PATH="${HOME}/.local/bin:/usr/local/bin:${PATH}"

if ! command -v godot >/dev/null 2>&1; then
  echo "godot not found. Run ./scripts/cloud-agent-install.sh first." >&2
  exit 1
fi

if [[ ! -f "${ROOT}/project.godot" ]]; then
  echo "No project.godot in ${ROOT}" >&2
  exit 1
fi

echo "==> Import"
godot --headless --path "${ROOT}" --import

echo "==> Script check (tools/ci_check.gd)"
godot --headless --path "${ROOT}" --script res://tools/ci_check.gd --check-only

echo "==> Run check script"
godot --headless --path "${ROOT}" --script res://tools/ci_check.gd

echo "Headless verify passed."
