#!/bin/sh
# Installs or updates Lunchbox on macOS and Linux, then opens it.
#   curl -fsSL https://raw.githubusercontent.com/noah-thing/lunchbox-releases/main/install.sh | sh
# LUNCHBOX_VERSION=0.1.1 picks a version, LUNCHBOX_DIR changes where it goes,
# LUNCHBOX_APPIMAGE=1 skips the .deb on Debian and Ubuntu, LUNCHBOX_NO_OPEN=1 does not open it.
set -eu

REPO=noah-thing/lunchbox-releases
say() { printf '%s\n' "$*"; }
fail() { printf 'Lunchbox: %s\n' "$*" >&2; exit 1; }
command -v curl >/dev/null 2>&1 || fail 'curl is needed to download Lunchbox.'

# The latest release is wherever GitHub's /latest redirect lands, which needs no API key or quota.
version=${LUNCHBOX_VERSION:-}
if [ -z "$version" ]; then
  latest=$(curl -fsSLI -o /dev/null -w '%{url_effective}' "https://github.com/$REPO/releases/latest") || fail 'could not reach GitHub.'
  version=${latest##*/v}
fi
case $version in ''|*/*) fail 'could not find the latest version.' ;; esac
base="https://github.com/$REPO/releases/download/v$version"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT INT TERM
fetch() { say "Downloading $1"; curl -fL --progress-bar -o "$tmp/$1" "$base/$1" || fail "could not download $1."; }

case $(uname -s) in
Darwin)
  case $(uname -m) in arm64) arch=arm64 ;; *) arch=x64 ;; esac
  file="Lunchbox-$version-mac-$arch.zip"
  fetch "$file"
  ditto -x -k "$tmp/$file" "$tmp/app"
  dir=${LUNCHBOX_DIR:-/Applications}
  [ -w "$dir" ] || dir="$HOME/Applications"
  mkdir -p "$dir"
  osascript -e 'quit app "Lunchbox"' >/dev/null 2>&1 || true
  rm -rf "$dir/Lunchbox.app"
  mv "$tmp/app/Lunchbox.app" "$dir/Lunchbox.app"
  # Downloaded with curl, the app carries no quarantine flag; clear it anyway in case it was copied.
  xattr -dr com.apple.quarantine "$dir/Lunchbox.app" 2>/dev/null || true
  say "Lunchbox $version is in $dir."
  [ -n "${LUNCHBOX_NO_OPEN:-}" ] || open "$dir/Lunchbox.app"
  ;;
Linux)
  [ "$(uname -m)" = x86_64 ] || fail "Lunchbox is built for x86_64 Linux; this machine is $(uname -m)."
  # On Debian and Ubuntu the .deb sets up the browser sandbox that Electron needs; elsewhere the
  # AppImage installs without root.
  if [ -z "${LUNCHBOX_APPIMAGE:-}" ] && command -v apt-get >/dev/null 2>&1 && command -v sudo >/dev/null 2>&1; then
    file="Lunchbox-$version-linux-amd64.deb"
    fetch "$file"
    say 'Installing the package (sudo asks for your password).'
    sudo apt-get install -y "$tmp/$file" || fail 'the package did not install.'
    say "Lunchbox $version is installed. Open it from your apps or run: lunchbox"
    run=lunchbox
  else
    file="Lunchbox-$version-linux-x86_64.AppImage"
    fetch "$file"
    data=${LUNCHBOX_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/lunchbox}
    mkdir -p "$data" "$HOME/.local/bin" "${XDG_DATA_HOME:-$HOME/.local/share}/applications"
    mv "$tmp/$file" "$data/Lunchbox.AppImage"
    chmod +x "$data/Lunchbox.AppImage"
    ln -sf "$data/Lunchbox.AppImage" "$HOME/.local/bin/lunchbox"
    curl -fsSL -o "$data/icon.png" "https://raw.githubusercontent.com/$REPO/main/icon.png" 2>/dev/null || true
    cat > "${XDG_DATA_HOME:-$HOME/.local/share}/applications/lunchbox.desktop" <<EOF
[Desktop Entry]
Name=Lunchbox
Comment=Every AI you use, working as one
Exec="$data/Lunchbox.AppImage" %U
Icon=$data/icon.png
Type=Application
Categories=Development;
EOF
    say "Lunchbox $version is in $data. Open it from your apps or run: lunchbox"
    if ! ldconfig -p 2>/dev/null | grep -q 'libfuse.so.2'; then
      say 'AppImages need FUSE 2. If Lunchbox does not start, install it:'
      say '  Ubuntu or Debian: sudo apt install libfuse2    Fedora: sudo dnf install fuse-libs    Arch: sudo pacman -S fuse2'
    fi
    run="$data/Lunchbox.AppImage"
  fi
  if [ -z "${LUNCHBOX_NO_OPEN:-}" ] && { [ -n "${DISPLAY:-}" ] || [ -n "${WAYLAND_DISPLAY:-}" ]; }; then
    nohup "$run" >/dev/null 2>&1 &
  fi
  ;;
*)
  fail 'this script is for macOS and Linux. On Windows run: irm https://raw.githubusercontent.com/noah-thing/lunchbox-releases/main/install.ps1 | iex'
  ;;
esac
