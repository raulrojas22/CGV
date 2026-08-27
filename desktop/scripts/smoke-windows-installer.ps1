param(
  [Parameter(Mandatory = $true)]
  [string]$InstallerPath
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$InstallerPath = (Resolve-Path $InstallerPath).Path
$InstallDir = Join-Path $env:LOCALAPPDATA "Programs\CGeV Desktop"
$UserDataDir = Join-Path $env:LOCALAPPDATA "CGV Desktop"
$StorageRoot = Join-Path $env:RUNNER_TEMP "CGeV Storage á CI"
$LogPath = Join-Path $UserDataDir "logs\startup.log"
$SettingsPath = Join-Path $UserDataDir "desktop-settings.json"
$MarkerPath = Join-Path $StorageRoot "data\preserve-after-uninstall.txt"

Remove-Item -Recurse -Force $InstallDir, $UserDataDir, $StorageRoot -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path (Split-Path $SettingsPath), (Split-Path $MarkerPath) | Out-Null
$SettingsJson = @{ schemaVersion = 1; storageRoot = $StorageRoot } | ConvertTo-Json
[System.IO.File]::WriteAllText($SettingsPath, $SettingsJson, [System.Text.UTF8Encoding]::new($false))
"CGeV data must survive uninstall" | Set-Content -Path $MarkerPath -Encoding utf8

$Installer = Start-Process -FilePath $InstallerPath -ArgumentList "/S" -Wait -PassThru
if ($Installer.ExitCode -ne 0) { throw "NSIS installer failed with exit code $($Installer.ExitCode)." }

$AppPath = Join-Path $InstallDir "CGeV Desktop.exe"
if (-not (Test-Path $AppPath)) { throw "Installed application not found: $AppPath" }

$AppProcess = Start-Process -FilePath $AppPath -PassThru
$Deadline = (Get-Date).AddMinutes(5)
$ReadyUrl = ""
while ((Get-Date) -lt $Deadline) {
  if ($AppProcess.HasExited) {
    $Log = if (Test-Path $LogPath) { Get-Content $LogPath -Raw } else { "no startup log" }
    throw "CGeV Desktop exited before becoming ready.`n$Log"
  }
  if (Test-Path $LogPath) {
    $Log = Get-Content $LogPath -Raw
    $Match = [regex]::Match($Log, "CGeV is ready at (http://127\.0\.0\.1:\d+)")
    if ($Match.Success) {
      $ReadyUrl = $Match.Groups[1].Value
      break
    }
  }
  Start-Sleep -Seconds 2
}
if (-not $ReadyUrl) {
  $Log = if (Test-Path $LogPath) { Get-Content $LogPath -Raw } else { "no startup log" }
  throw "Timed out waiting for CGeV is ready.`n$Log"
}

$Response = Invoke-WebRequest -Uri $ReadyUrl -UseBasicParsing -TimeoutSec 30
if ($Response.StatusCode -ne 200) { throw "CGV localhost returned HTTP $($Response.StatusCode)." }

if (-not $AppProcess.CloseMainWindow()) { throw "CGeV Desktop did not accept a normal window-close request." }
if (-not $AppProcess.WaitForExit(30000)) {
  Stop-Process -Id $AppProcess.Id -Force -ErrorAction SilentlyContinue
  throw "CGeV Desktop did not exit after its window was closed."
}
Start-Sleep -Seconds 3

$BundledR = Get-CimInstance Win32_Process | Where-Object {
  $_.Name -match '^R(script|term)?\.exe$' -and (
  ($_.ExecutablePath -and $_.ExecutablePath.StartsWith($InstallDir, [System.StringComparison]::OrdinalIgnoreCase)) -or
  ($_.CommandLine -and $_.CommandLine.Contains("win32-x64"))
  )
}
if ($BundledR) {
  $BundledR | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
  throw "Bundled R process remained after CGeV Desktop closed."
}

$UninstallerPath = Join-Path $InstallDir "Uninstall CGeV Desktop.exe"
if (-not (Test-Path $UninstallerPath)) { throw "NSIS uninstaller not found: $UninstallerPath" }
$Uninstaller = Start-Process -FilePath $UninstallerPath -ArgumentList "/S" -Wait -PassThru
if ($Uninstaller.ExitCode -ne 0) { throw "NSIS uninstaller failed with exit code $($Uninstaller.ExitCode)." }
if (-not (Test-Path $MarkerPath)) { throw "Uninstall removed the selected CGeV data folder." }

Write-Host "windows-installer-smoke-ok url=$ReadyUrl storage=$StorageRoot"
