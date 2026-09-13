#!/usr/bin/env bash
# LFD — LLMs for Dummies. Made by Pakun.
# Install like hydra: one command, then `sudo lfd`
#
#   curl -fsSL https://raw.githubusercontent.com/brazyqueso/lfd/main/install.sh | sudo bash
#   sudo lfd
set -euo pipefail

REPO_USER="${LFD_GITHUB_USER:-brazyqueso}"
REPO_NAME="${LFD_GITHUB_REPO:-lfd}"
BRANCH="${LFD_GITHUB_BRANCH:-main}"
RAW="https://raw.githubusercontent.com/${REPO_USER}/${REPO_NAME}/${BRANCH}/lfd.sh"
BIN="/usr/local/bin/lfd"

if [[ ${EUID} -ne 0 ]]; then
  echo "LFD needs root to land in ${BIN} (same as hydra/bettercap)."
  echo "curl -fsSL ${RAW%lfd.sh}install.sh | sudo bash"
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y dialog curl ca-certificates

tmp="$(mktemp)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$HERE/lfd.sh" && "${LFD_FORCE_REMOTE:-}" != 1 ]]; then
  install -m 0755 "$HERE/lfd.sh" "$BIN"
else
  echo "Downloading LFD..."
  curl -fsSL "$RAW" -o "$tmp"
  install -m 0755 "$tmp" "$BIN"
  rm -f "$tmp"
fi

if [[ -n ${SUDO_USER:-} ]]; then
  user_home="$(getent passwd "$SUDO_USER" | cut -d: -f6)"
  mkdir -p "$user_home/.local/bin"
  install -m 0755 "$BIN" "$user_home/.local/bin/lfd"
  chown "$SUDO_USER:" "$user_home/.local/bin/lfd" 2>/dev/null || true
fi

echo
echo "LFD installed."
echo "Launch it the same way you launch hydra:"
echo
echo "    sudo lfd"
echo
