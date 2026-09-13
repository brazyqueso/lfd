#!/usr/bin/env bash
# LFD installer — LLMs for Dummies. Made by Pakun.
#   curl -fsSL https://raw.githubusercontent.com/brazyqueso/lfd/main/install.sh | bash
set -euo pipefail

REPO_USER="${LFD_GITHUB_USER:-brazyqueso}"
REPO_NAME="${LFD_GITHUB_REPO:-lfd}"
BRANCH="${LFD_GITHUB_BRANCH:-main}"
RAW="https://raw.githubusercontent.com/${REPO_USER}/${REPO_NAME}/${BRANCH}/lfd.sh"
PREFIX="${PREFIX:-$HOME/.local/bin}"

mkdir -p "$PREFIX" "$HOME/.lfd"

echo "LFD — LLMs for Dummies   Made by Pakun"
echo "Downloading $RAW"

if [[ -f "$(dirname "${BASH_SOURCE[0]}")/lfd.sh" && "${LFD_FORCE_REMOTE:-}" != 1 ]]; then
  install -m 0755 "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lfd.sh" "$PREFIX/lfd"
else
  tmp="$(mktemp)"
  curl -fsSL "$RAW" -o "$tmp"
  install -m 0755 "$tmp" "$PREFIX/lfd"
  rm -f "$tmp"
fi

if ! command -v dialog >/dev/null 2>&1; then
  echo "Installing dialog..."
  sudo apt-get update -qq
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y dialog curl
fi

if [[ -f $HOME/.bashrc ]] && ! grep -q '\.local/bin' "$HOME/.bashrc"; then
  echo 'export PATH="$HOME/.local/bin:$PATH"' >>"$HOME/.bashrc"
fi

echo
echo "Installed: $PREFIX/lfd"
echo "source ~/.bashrc"
echo "lfd"
echo "lfd wizard"
