param(
  [Parameter(Mandatory = $true)]
  [string]$InstallerPath
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$InstallerPath = (Resolve-Path $InstallerPath).Path
$InstallDir = Join-Path $env:LOCALAPPDATA "Programs\CGV Desktop"
$UserDataDir = Join-Path $env:LOCALAPPDATA "CGV Desktop"
$StorageRoot = Join-Path $env:RUNNER_TEMP "CGV Storage á CI"
$LogPath = Join-Path $UserDataDir "logs\startup.log"
$SettingsPath = Join-Path $UserDataDir "desktop-settings.json"
$MarkerPath = Join-Path $StorageRoot "data\preserve-after-uninstall.txt"
$ExpectedVideoPath = Join-Path $InstallDir "resources\app\www\CTV_Animated.mp4"
$InstalledAppRoot = Join-Path $InstallDir "resources\app"
$SourceManifestPath = Join-Path $InstalledAppRoot "app-source-manifest.json"
$LiteralInstallDir = Join-Path $InstallDir '$INSTDIR'

function Install-CgvDesktop {
  $Installer = Start-Process -FilePath $InstallerPath -ArgumentList "/S" -Wait -PassThru
  if ($Installer.ExitCode -ne 0) { throw "NSIS installer failed with exit code $($Installer.ExitCode)." }
}

function Assert-InstalledLayout {
  $AppPath = Join-Path $InstallDir "CGV Desktop.exe"
  if (-not (Test-Path $AppPath)) { throw "Installed application not found: $AppPath" }
  if (-not (Test-Path $ExpectedVideoPath)) { throw "Pre-compressed Home video was not installed at its canonical path: $ExpectedVideoPath" }
  $GuideVideos = @(Get-ChildItem (Join-Path $InstalledAppRoot "www\screencasts\*.mp4") -File -ErrorAction SilentlyContinue)
  if ($GuideVideos.Count -lt 35) { throw "CGV Guide media bundle is incomplete; found $($GuideVideos.Count) of 35 required videos." }
  if (-not (Test-Path $SourceManifestPath)) { throw "Application-source manifest was not installed: $SourceManifestPath" }
  if (Test-Path $LiteralInstallDir) { throw "NSIS created an invalid literal `$INSTDIR directory: $LiteralInstallDir" }

  $SourceManifest = Get-Content $SourceManifestPath -Raw | ConvertFrom-Json
  if ($SourceManifest.schemaVersion -ne 1) { throw "Unexpected application-source manifest schema." }
  if ($SourceManifest.appVersion -ne "0.1.3") { throw "Installer contains CGV Desktop $($SourceManifest.appVersion), expected 0.1.3." }
  if ($env:CGV_DESKTOP_SOURCE_REVISION -and $SourceManifest.sourceRevision -ne $env:CGV_DESKTOP_SOURCE_REVISION) {
    throw "Installer source revision $($SourceManifest.sourceRevision) does not match workflow revision $env:CGV_DESKTOP_SOURCE_REVISION."
  }
  foreach ($Property in $SourceManifest.files.PSObject.Properties) {
    $RelativePath = $Property.Name -replace '/', '\'
    $InstalledSourcePath = Join-Path $InstalledAppRoot $RelativePath
    if (-not (Test-Path $InstalledSourcePath)) { throw "Manifest source file was not installed: $($Property.Name)" }
    $ActualHash = (Get-FileHash -Algorithm SHA256 $InstalledSourcePath).Hash.ToLowerInvariant()
    if ($ActualHash -ne [string]$Property.Value.sha256) {
      throw "Installed source hash mismatch: $($Property.Name)"
    }
  }

  $UiSource = Get-Content (Join-Path $InstalledAppRoot "ui.R") -Raw
  foreach ($Marker in @("app-optional-uploads-panel", "desktop-organism-modal", "cgv_desktop_downloads_page()", "Mixed sources")) {
    if (-not $UiSource.Contains($Marker)) { throw "Installer contains an obsolete Shiny UI; missing marker: $Marker" }
  }
  $HomeSource = Get-Content (Join-Path $InstalledAppRoot "www\home_preview_cgv.html") -Raw
  foreach ($Marker in @("Live gene suggestions", "transcript alignment", "25 installable reference organisms", "Explore CGV Desktop")) {
    if (-not $HomeSource.Contains($Marker)) { throw "Installer contains an obsolete Home; missing marker: $Marker" }
  }
  return $AppPath
}

function Start-CgvDesktopAndWait {
  param([string]$AppPath)

  Remove-Item -Force $LogPath -ErrorAction SilentlyContinue
  $AppProcess = Start-Process -FilePath $AppPath -PassThru
  $Deadline = (Get-Date).AddMinutes(5)
  $ReadyUrl = ""
  while ((Get-Date) -lt $Deadline) {
    if ($AppProcess.HasExited) {
      $Log = if (Test-Path $LogPath) { Get-Content $LogPath -Raw } else { "no startup log" }
      throw "CGV Desktop exited before becoming ready.`n$Log"
    }
    if (Test-Path $LogPath) {
      $Log = Get-Content $LogPath -Raw
      $Match = [regex]::Match($Log, "CGV renderer loaded at (http://127\.0\.0\.1:\d+)")
      if ($Match.Success) {
        $ReadyUrl = $Match.Groups[1].Value
        break
      }
    }
    Start-Sleep -Seconds 2
  }
  if (-not $ReadyUrl) {
    $Log = if (Test-Path $LogPath) { Get-Content $LogPath -Raw } else { "no startup log" }
    throw "Timed out waiting for the CGV renderer to finish loading.`n$Log"
  }

  $Response = Invoke-WebRequest -Uri $ReadyUrl -UseBasicParsing -TimeoutSec 30
  if ($Response.StatusCode -ne 200) { throw "CGV localhost returned HTTP $($Response.StatusCode)." }
  return @{ Process = $AppProcess; ReadyUrl = $ReadyUrl }
}

function Get-BundledRProcesses {
  return Get-CimInstance Win32_Process | Where-Object {
    $_.Name -match '^R(script|term)?\.exe$' -and (
    ($_.ExecutablePath -and $_.ExecutablePath.StartsWith($InstallDir, [System.StringComparison]::OrdinalIgnoreCase)) -or
    ($_.CommandLine -and $_.CommandLine.Contains("win32-x64"))
    )
  }
}

function Wait-ForNoBundledRProcesses {
  param([int]$TimeoutSeconds = 15)

  $Deadline = (Get-Date).AddSeconds($TimeoutSeconds)
  $Remaining = @()
  do {
    $Remaining = @(Get-BundledRProcesses)
    if ($Remaining.Count -eq 0) { return }
    Start-Sleep -Milliseconds 500
  } while ((Get-Date) -lt $Deadline)

  return $Remaining
}

function Format-BundledRProcesses {
  param([object[]]$Processes)

  return (($Processes | ForEach-Object {
    "pid=$($_.ProcessId) parent=$($_.ParentProcessId) path=$($_.ExecutablePath) command=$($_.CommandLine)"
  }) -join "`n")
}

function Wait-ForAutomaticRecovery {
  param(
    [System.Diagnostics.Process]$AppProcess
  )

  $Deadline = (Get-Date).AddMinutes(5)
  while ((Get-Date) -lt $Deadline) {
    if ($AppProcess.HasExited) {
      $Log = if (Test-Path $LogPath) { Get-Content $LogPath -Raw } else { "no startup log" }
      throw "CGV Desktop exited instead of recovering its analysis process.`n$Log"
    }
    if (Test-Path $LogPath) {
      $Log = Get-Content $LogPath -Raw
      $Matches = [regex]::Matches($Log, "CGV recovered automatically at (http://127\.0\.0\.1:\d+)")
      if ($Matches.Count -gt 0) {
        $RecoveredUrl = $Matches[$Matches.Count - 1].Groups[1].Value
        $Response = Invoke-WebRequest -Uri $RecoveredUrl -UseBasicParsing -TimeoutSec 30
        if ($Response.StatusCode -ne 200) { throw "Recovered CGV localhost returned HTTP $($Response.StatusCode)." }
        return $RecoveredUrl
      }
    }
    Start-Sleep -Seconds 2
  }
  $Log = if (Test-Path $LogPath) { Get-Content $LogPath -Raw } else { "no startup log" }
  throw "Timed out waiting for automatic analysis recovery.`n$Log"
}

Remove-Item -Recurse -Force $InstallDir, $UserDataDir, $StorageRoot -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path (Split-Path $SettingsPath), (Split-Path $MarkerPath) | Out-Null
$SettingsJson = @{ schemaVersion = 1; storageRoot = $StorageRoot } | ConvertTo-Json
[System.IO.File]::WriteAllText($SettingsPath, $SettingsJson, [System.Text.UTF8Encoding]::new($false))
"CGV data must survive uninstall" | Set-Content -Path $MarkerPath -Encoding utf8

Install-CgvDesktop
$AppPath = Assert-InstalledLayout
$FirstRun = Start-CgvDesktopAndWait -AppPath $AppPath

# A local R/Shiny failure must recover without asking the user to press Reload
# repeatedly. The Electron process and selected data location remain intact.
$BundledR = Get-BundledRProcesses
if (-not $BundledR) { throw "No bundled R process was found for the automatic-recovery smoke test." }
$BundledR | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
$RecoveredUrl = Wait-ForAutomaticRecovery -AppProcess $FirstRun.Process

# Reinstall while CGV and its bundled R child are active. NSIS must close both,
# replace pre-compressed assets, and keep the selected data location intact.
Install-CgvDesktop
if (-not $FirstRun.Process.WaitForExit(30000)) {
  Stop-Process -Id $FirstRun.Process.Id -Force -ErrorAction SilentlyContinue
  throw "NSIS did not close the running CGV Desktop process during reinstall."
}
$BundledR = @(Wait-ForNoBundledRProcesses)
if ($BundledR) {
  $ProcessDetails = Format-BundledRProcesses -Processes $BundledR
  $BundledR | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
  throw "Bundled R process remained after NSIS reinstalled CGV Desktop.`n$ProcessDetails"
}

$AppPath = Assert-InstalledLayout
if (-not (Test-Path $MarkerPath)) { throw "Reinstall removed the selected CGV data folder." }
$SecondRun = Start-CgvDesktopAndWait -AppPath $AppPath

if (-not $SecondRun.Process.CloseMainWindow()) { throw "CGV Desktop did not accept a normal window-close request." }
if (-not $SecondRun.Process.WaitForExit(30000)) {
  Stop-Process -Id $SecondRun.Process.Id -Force -ErrorAction SilentlyContinue
  throw "CGV Desktop did not exit after its window was closed."
}
$BundledR = @(Wait-ForNoBundledRProcesses)
if ($BundledR) {
  $ProcessDetails = Format-BundledRProcesses -Processes $BundledR
  $BundledR | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
  throw "Bundled R process remained after CGV Desktop closed.`n$ProcessDetails"
}

$UninstallerPath = Join-Path $InstallDir "Uninstall CGV Desktop.exe"
if (-not (Test-Path $UninstallerPath)) { throw "NSIS uninstaller not found: $UninstallerPath" }
$Uninstaller = Start-Process -FilePath $UninstallerPath -ArgumentList "/S" -Wait -PassThru
if ($Uninstaller.ExitCode -ne 0) { throw "NSIS uninstaller failed with exit code $($Uninstaller.ExitCode)." }
if (-not (Test-Path $MarkerPath)) { throw "Uninstall removed the selected CGV data folder." }

Write-Host "windows-installer-smoke-ok firstUrl=$($FirstRun.ReadyUrl) recoveredUrl=$RecoveredUrl secondUrl=$($SecondRun.ReadyUrl) source=$env:CGV_DESKTOP_SOURCE_REVISION storage=$StorageRoot"
