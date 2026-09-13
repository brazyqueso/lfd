#!/usr/bin/env bash
# LFD — LLMs for Dummies. Made by Pakun & iinze0.
#   curl -fsSL https://raw.githubusercontent.com/brazyqueso/lfd/main/install.sh | sudo bash
#   sudo lfd
set -euo pipefail

REPO_USER="${LFD_GITHUB_USER:-brazyqueso}"
REPO_NAME="${LFD_GITHUB_REPO:-lfd}"
BRANCH="${LFD_GITHUB_BRANCH:-main}"
RAW="https://raw.githubusercontent.com/${REPO_USER}/${REPO_NAME}/${BRANCH}/lfd.sh"
BIN="/usr/bin/lfd"

if [[ ${EUID} -ne 0 ]]; then
  echo "LFD needs root to land in ${BIN}."
  echo "curl -fsSL https://raw.githubusercontent.com/${REPO_USER}/${REPO_NAME}/${BRANCH}/install.sh | sudo bash"
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y dialog curl ca-certificates

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

local_copy=""
# curl | bash has no BASH_SOURCE — never treat that as a local file
if [[ -n ${BASH_SOURCE[0]:-} && ${BASH_SOURCE[0]} != bash && ${BASH_SOURCE[0]} != - ]]; then
  src_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd || true)"
  if [[ -n ${src_dir:-} && -f "$src_dir/lfd.sh" ]]; then
    local_copy="$src_dir/lfd.sh"
  fi
fi

if [[ -n $local_copy && ${LFD_FORCE_REMOTE:-} != 1 ]]; then
  echo "Installing from $local_copy"
  install -m 0755 "$local_copy" "$BIN"
else
  echo "Downloading LFD from $RAW"
  curl -fsSL "$RAW" -o "$tmp"
  # sanity: must look like the real script
  head -1 "$tmp" | grep -q '^#!' || { echo "download was not a script"; exit 1; }
  grep -q 'LFD' "$tmp" || { echo "download was not LFD"; exit 1; }
  install -m 0755 "$tmp" "$BIN"
fi

if [[ -n ${SUDO_USER:-} ]]; then
  user_home="$(getent passwd "$SUDO_USER" | cut -d: -f6)"
  if [[ -n ${user_home:-} && -d $user_home ]]; then
    mkdir -p "$user_home/.local/bin"
    install -m 0755 "$BIN" "$user_home/.local/bin/lfd"
    chown "$SUDO_USER:" "$user_home/.local/bin/lfd" 2>/dev/null || true
  fi
fi

command -v lfd >/dev/null || true

mkdir -p /usr/share/pixmaps /usr/share/applications
cat >/usr/share/pixmaps/lfd.svg <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64">
  <rect width="64" height="64" fill="#0a0a0a"/>
  <rect x="2" y="2" width="60" height="60" fill="none" stroke="#c41e3a" stroke-width="3"/>
  <path fill="#c41e3a" d="M10 14h8v36H10zm0 28h18v8H10zM30 14h8v36h-8zm0 0h16v8H30zm0 14h12v8H30zM50 14h8v36h-8zm-2 0h16v8H48zm-2 28h16v8H46z"/>
</svg>
SVG
cat >/usr/share/applications/lfd.desktop <<'EOF'
[Desktop Entry]
Name=LFD
GenericName=LLMs for Dummies
Comment=Local LLMs on Kali. Made by Pakun & iinze0.
Exec=x-terminal-emulator -e sudo lfd
Icon=lfd
Terminal=false
Type=Application
Categories=System;Utility;Security;
Keywords=llm;ollama;kali;pakun;
EOF

echo
echo "LFD installed at $BIN"
echo "Launch:"
echo "    sudo lfd"
echo