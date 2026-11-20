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

# The wordmark settles out of the agents' alphabets, the way the app's welcome screen does, then a
# band of light passes over it. Only in a real terminal wide enough for it; anywhere else, the two
# plain lines are enough.
finale() {
  cols=$(tput cols 2>/dev/null || echo 0)
  if [ ! -t 1 ] || [ -n "${NO_COLOR:-}" ] || [ "${TERM:-dumb}" = dumb ] || [ "$cols" -lt 60 ]; then
    say "$1"; say "$2"; return
  fi
  printf '\033[?25l'
  awk -v l1="$1" -v l2="$2" -v cols="$cols" '
    function px(r, c) { return substr(font[r], c, 1) == "#" }
    function ink(n) { return "\033[38;5;" n "m" }
    BEGIN {
      split("#....,#....,#....,#....,#####", L, ","); split("#...#,#...#,#...#,#...#,.###.", U, ",")
      split("#...#,##..#,#.#.#,#..##,#...#", N, ","); split(".####,#....,#....,#....,.####", C, ",")
      split("#...#,#...#,#####,#...#,#...#", H, ","); split("####.,#...#,####.,#...#,####.", B, ",")
      split(".###.,#...#,#...#,#...#,.###.", O, ","); split("#...#,.#.#.,..#..,.#.#.,#...#", X, ",")
      for (r = 1; r <= 5; r++) font[r] = L[r] "." U[r] "." N[r] "." C[r] "." H[r] "." B[r] "." O[r] "." X[r]
      fw = length(font[1]); cw = cols >= 100 ? 2 : 1; W = fw * cw; rows = 7
      pad = sprintf("%" int((cols - W) / 2 > 2 ? 2 : 1) "s", "")
      glyphs = ".:-=+*#%@.-01:/|X,oO0@"; srand()
      S = 16; SW = 18; F = S + SW + 2
      for (r = 1; r <= 5; r++) for (c = 1; c <= fw; c++) at[r, c] = int(c / fw * S * 0.75 + rand() * S * 0.25)
      for (f = 0; f <= F; f++) {
        band = (f - S) / SW * (fw + 16) - 8
        out = ""
        for (r = 0; r <= rows - 1; r++) {
          line = pad
          for (c = 1; c <= fw; c++) {
            lit = r >= 1 && r <= 5 && px(r, c)
            if (lit && f >= at[r, c]) {
              d = c - band; glow = (f > S && f < F) ? exp(-d * d / 10) : 0
              cell = glow > 0.55 ? ink(231) "\033[1m" : glow > 0.15 ? ink(253) : ink(f >= F ? 252 : 248)
              ch = cw == 2 ? "██" : "█"
              line = line cell ch "\033[0m"
            } else {
              noise = (r >= 1 && r <= 5) ? (lit ? 1 : 0.5) : 0.25
              left = f < S ? noise * (1 - f / (S + 4)) : 0
              if (rand() < left) { g = substr(glyphs, int(rand() * length(glyphs)) + 1, 1); line = line ink(236 + int(rand() * 5)) (cw == 2 ? g " " : g) "\033[0m" }
              else line = line (cw == 2 ? "  " : " ")
            }
          }
          out = out line "\n"
        }
        printf "%s", out
        if (f == F) break
        fflush(); system("sleep 0.035"); printf "\033[%dA", rows
      }
      printf "%s\033[1m%s\033[0m\n%s\033[38;5;247m%s\033[0m\n", pad, l1, pad, l2
    }'
  printf '\033[?25h'
}

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
  if [ -n "${LUNCHBOX_NO_OPEN:-}" ]; then finale "Lunchbox $version is ready" "It is in $dir."
  else finale "Lunchbox $version is ready" 'Every AI you use, working as one. Opening it now.'; open "$dir/Lunchbox.app"; fi
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
    finale "Lunchbox $version is ready" 'Open it from your apps, or run: lunchbox'
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
    finale "Lunchbox $version is ready" 'Open it from your apps, or run: lunchbox'
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
