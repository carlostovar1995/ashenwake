#!/usr/bin/env bash
# Idempotent Cloud Agent install: pin Godot Linux editor, put `godot` on PATH,
# then import the project so .godot/ exists for later headless checks.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

VERSION_FILE="${ROOT}/.godot-version"
if [[ ! -f "${VERSION_FILE}" ]]; then
  echo "Missing ${VERSION_FILE}" >&2
  exit 1
fi

GODOT_VERSION="$(tr -d '[:space:]' < "${VERSION_FILE}")"
if [[ -z "${GODOT_VERSION}" ]]; then
  echo ".godot-version is empty" >&2
  exit 1
fi

ARCH="$(uname -m)"
case "${ARCH}" in
  x86_64|amd64) GODOT_PLATFORM="linux.x86_64" ;;
  aarch64|arm64) GODOT_PLATFORM="linux.arm64" ;;
  *)
    echo "Unsupported architecture: ${ARCH}" >&2
    exit 1
    ;;
esac

CACHE_DIR="${HOME}/.local/share/godot-editor/${GODOT_VERSION}"
mkdir -p "${CACHE_DIR}" "${HOME}/.local/bin"

ZIP_NAME="Godot_v${GODOT_VERSION}_${GODOT_PLATFORM}.zip"
ZIP_PATH="${CACHE_DIR}/${ZIP_NAME}"
# Release zip extracts to Godot_v4.7-stable_linux.x86_64 (dot vs underscore).
EXTRACTED_NAME="Godot_v${GODOT_VERSION}_${GODOT_PLATFORM}"
EXTRACTED_PATH="${CACHE_DIR}/${EXTRACTED_NAME}"

DOWNLOAD_URL="https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}/${ZIP_NAME}"

need_download=1
if [[ -x "${EXTRACTED_PATH}" ]]; then
  need_download=0
fi

if [[ "${need_download}" -eq 1 ]]; then
  echo "Downloading Godot ${GODOT_VERSION} (${GODOT_PLATFORM})..."
  curl -fL --retry 3 --retry-delay 2 -o "${ZIP_PATH}.tmp" "${DOWNLOAD_URL}"
  mv "${ZIP_PATH}.tmp" "${ZIP_PATH}"
  unzip -o -q "${ZIP_PATH}" -d "${CACHE_DIR}"
  rm -f "${ZIP_PATH}"
  chmod +x "${EXTRACTED_PATH}"
fi

link_godot() {
  local dest="$1"
  ln -sfn "${EXTRACTED_PATH}" "${dest}"
}

link_godot "${HOME}/.local/bin/godot"

if [[ -w /usr/local/bin ]]; then
  link_godot /usr/local/bin/godot
elif command -v sudo >/dev/null 2>&1; then
  sudo ln -sfn "${EXTRACTED_PATH}" /usr/local/bin/godot
fi

export PATH="${HOME}/.local/bin:/usr/local/bin:${PATH}"

if ! command -v godot >/dev/null 2>&1; then
  echo "godot is not on PATH after install" >&2
  exit 1
fi

echo "Using $(command -v godot)"
godot --version

if [[ ! -f "${ROOT}/project.godot" ]]; then
  echo "No project.godot yet — skipping import. Copy the Godot project into this repo and re-run."
  exit 0
fi

echo "Importing project (headless)..."
godot --headless --path "${ROOT}" --import
echo "Godot import finished."
