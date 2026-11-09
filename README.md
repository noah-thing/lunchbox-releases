# Lunchbox releases

Installers for [Lunchbox](https://github.com/noah-thing/lunchbox), and the feed the app reads for updates and messages.

## Install

**macOS and Linux**

```sh
curl -fsSL https://raw.githubusercontent.com/noah-thing/lunchbox-releases/main/install.sh | sh
```

**Windows** (PowerShell)

```powershell
irm https://raw.githubusercontent.com/noah-thing/lunchbox-releases/main/install.ps1 | iex
```

The script downloads the latest version for your computer, installs it and opens Lunchbox. Run it again any time to update; Lunchbox also updates itself.

| | What it installs |
| --- | --- |
| macOS | `Lunchbox.app` in Applications, Apple silicon or Intel |
| Linux | The `.deb` on Debian and Ubuntu, otherwise the AppImage with a menu entry and a `lunchbox` command |
| Windows | The installer for your user, x64 or Arm |

## Download instead

Every file is under [Releases](https://github.com/noah-thing/lunchbox-releases/releases/latest).

- **macOS:** open the `.dmg` and drag Lunchbox to Applications. Lunchbox is not signed yet, so the first time, right click it and choose Open.
- **Windows:** run `Lunchbox-Setup-<version>.exe`. If Windows says it protected your PC, choose More info, then Run anyway.
- **Linux:** `sudo apt install ./Lunchbox-<version>-linux-amd64.deb`, or make the AppImage executable and run it (newer Ubuntu needs `sudo apt install libfuse2`).

## The feed

`notices.json` is signed. The app ignores it unless the signature matches the key built into Lunchbox.
