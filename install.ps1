# Installs or updates Lunchbox on Windows, then opens it.
#   irm https://raw.githubusercontent.com/noah-thing/lunchbox-releases/main/install.ps1 | iex
# $env:LUNCHBOX_VERSION = '0.1.1' picks a version first.
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

$repo = 'noah-thing/lunchbox-releases'
$version = $env:LUNCHBOX_VERSION
if (-not $version) {
  $release = Invoke-RestMethod "https://api.github.com/repos/$repo/releases/latest" -Headers @{ 'User-Agent' = 'lunchbox-installer' }
  $version = $release.tag_name.TrimStart('v')
}

$file = "Lunchbox-Setup-$version.exe"
$setup = Join-Path $env:TEMP $file
Write-Host "Downloading $file"
Invoke-WebRequest "https://github.com/$repo/releases/download/v$version/$file" -OutFile $setup -UseBasicParsing

# A running copy would hold its files open; the installer replaces it.
Get-Process Lunchbox -ErrorAction SilentlyContinue | Stop-Process -Force
Write-Host 'Installing'
# /S installs for this user without questions; the installer picks x64 or Arm itself.
Start-Process $setup -ArgumentList '/S' -Wait
Remove-Item $setup -ErrorAction SilentlyContinue

$exe = @(
  (Join-Path $env:LOCALAPPDATA 'Programs\Lunchbox\Lunchbox.exe'),
  (Join-Path $env:ProgramFiles 'Lunchbox\Lunchbox.exe')
) | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $exe) { throw 'Lunchbox installed, but its program file was not found. Open it from the Start menu.' }
Write-Host "Lunchbox $version is installed."
Start-Process $exe
