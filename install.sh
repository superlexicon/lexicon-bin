#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_SRC="${SCRIPT_DIR}/bin/lexicon-node"
INSTALL_DIR="${INSTALL_DIR:-${HOME}/.local/bin}"

if [[ ! -f "${BIN_SRC}" ]]; then
  echo "error: ${BIN_SRC} not found" >&2
  exit 1
fi

mkdir -p "${INSTALL_DIR}"
install -m 0755 "${BIN_SRC}" "${INSTALL_DIR}/lexicon-node"
echo "Installed lexicon-node -> ${INSTALL_DIR}/lexicon-node"

if [[ ":${PATH}:" != *":${INSTALL_DIR}:"* ]]; then
  echo "Note: add ${INSTALL_DIR} to your PATH:"
  echo "  export PATH=\"${INSTALL_DIR}:\$PATH\""
fi
