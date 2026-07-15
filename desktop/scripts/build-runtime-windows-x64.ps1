param(
  [string]$LockFile = ""
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

if (-not [Environment]::Is64BitOperatingSystem) {
  throw "The Windows x64 runtime must be built on a 64-bit Windows host."
}

$DesktopDir = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$RepoDir = (Resolve-Path (Join-Path $DesktopDir "..")).Path
if (-not $LockFile) { $LockFile = Join-Path $DesktopDir "runtime-windows-lock.json" }
$LockFile = (Resolve-Path $LockFile).Path
$Lock = Get-Content $LockFile -Raw | ConvertFrom-Json
if ($Lock.platform -ne "win32-x64") { throw "Unexpected runtime platform: $($Lock.platform)" }

$RuntimeRoot = Join-Path $DesktopDir "resources\r\win32-x64"
$DownloadRoot = Join-Path ([System.IO.Path]::GetTempPath()) "cgv-desktop-runtime-downloads"
New-Item -ItemType Directory -Force -Path $DownloadRoot | Out-Null
$MsysRoot = if ($env:CGV_MSYS2_ROOT) { $env:CGV_MSYS2_ROOT } else { "C:\msys64" }
$Bash = Join-Path $MsysRoot "usr\bin\bash.exe"
$Pacman = Join-Path $MsysRoot "usr\bin\pacman.exe"
if (-not (Test-Path $Bash)) {
  throw "MSYS2 was not found at $MsysRoot. Set CGV_MSYS2_ROOT or install MSYS2 with MinGW64 GCC and make."
}
if (-not (Test-Path $Pacman)) { throw "MSYS2 pacman was not found at $Pacman." }

function Convert-ToMsysPath([string]$WindowsPath) {
  $Full = [System.IO.Path]::GetFullPath($WindowsPath).Replace("\", "/")
  if ($Full -match '^([A-Za-z]):(.*)$') {
    return "/$($Matches[1].ToLowerInvariant())$($Matches[2])"
  }
  return $Full
}

function Get-VerifiedDownload {
  param([string]$Url, [string]$Sha256, [string]$FileName)
  $Target = Join-Path $DownloadRoot $FileName
  if (-not (Test-Path $Target)) {
    Invoke-WebRequest -Uri $Url -OutFile $Target
  }
  $Actual = (Get-FileHash -Algorithm SHA256 $Target).Hash.ToLowerInvariant()
  if ($Actual -ne $Sha256.ToLowerInvariant()) {
    Remove-Item -Force $Target -ErrorAction SilentlyContinue
    throw "SHA-256 mismatch for $FileName. Expected $Sha256, found $Actual."
  }
  return $Target
}

$RInstaller = Get-VerifiedDownload $Lock.r.url $Lock.r.sha256 "R-$($Lock.r.version)-win.exe"
$RtoolsArchive = Get-VerifiedDownload $Lock.rtools44.url $Lock.rtools44.sha256 "rtools44-toolchain-libs-$($Lock.rtools44.bundle)-$($Lock.rtools44.version).tar.zst"
$LastzArchive = Get-VerifiedDownload $Lock.lastz.url $Lock.lastz.sha256 "lastz-$($Lock.lastz.version).tar.gz"
$MmanPackage = Get-VerifiedDownload $Lock.mmanWin32.url $Lock.mmanWin32.sha256 "mingw-w64-x86_64-mman-win32-$($Lock.mmanWin32.version)-any.pkg.tar.zst"
$CranIndexUrl = "$($Lock.cranRepository.url)/bin/windows/contrib/4.4/PACKAGES.gz"
$null = Get-VerifiedDownload $CranIndexUrl $Lock.cranRepository.windowsR44IndexSha256 "cran-$($Lock.cranRepository.snapshotDate)-windows-r44-PACKAGES.gz"
foreach ($Index in $Lock.bioconductorRepository.indexes) {
  $null = Get-VerifiedDownload $Index.url $Index.sha256 "bioconductor-$($Lock.bioconductorVersion)-$($Index.name)-PACKAGES.gz"
}

Remove-Item -Recurse -Force $RuntimeRoot -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $RuntimeRoot | Out-Null
$InstallArgs = @(
  "/VERYSILENT",
  "/SUPPRESSMSGBOXES",
  "/NORESTART",
  "/CURRENTUSER",
  "/MERGETASKS=!desktopicon,!quicklaunchicon,!recordversion",
  "/DIR=`"$RuntimeRoot`""
)
$Install = Start-Process -FilePath $RInstaller -ArgumentList $InstallArgs -Wait -PassThru
if ($Install.ExitCode -ne 0) { throw "R installer failed with exit code $($Install.ExitCode)." }

$RscriptCandidates = @(
  (Join-Path $RuntimeRoot "bin\Rscript.exe"),
  (Join-Path $RuntimeRoot "bin\x64\Rscript.exe")
)
$Rscript = $RscriptCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $Rscript) { throw "Rscript.exe was not installed under $RuntimeRoot." }

$RtoolsExtractRoot = Join-Path $DownloadRoot "rtools44-$($Lock.rtools44.version)-$($Lock.rtools44.bundle)"
Remove-Item -Recurse -Force $RtoolsExtractRoot -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $RtoolsExtractRoot | Out-Null
$RtoolsArchiveMsys = Convert-ToMsysPath $RtoolsArchive
$RtoolsExtractRootMsys = Convert-ToMsysPath $RtoolsExtractRoot
& $Bash -lc "/usr/bin/tar --zstd -xf '$RtoolsArchiveMsys' -C '$RtoolsExtractRootMsys'"
if ($LASTEXITCODE -ne 0) { throw "Locked Rtools44 toolchain extraction failed." }

$RtoolsSoft = Join-Path $RtoolsExtractRoot "x86_64-w64-mingw32.static.posix"
$RtoolsBin = Join-Path $RtoolsSoft "bin"
$MsysUsrBin = Join-Path $MsysRoot "usr\bin"
$env:R_CUSTOM_TOOLS_SOFT = $RtoolsSoft.Replace("\", "/")
$env:R_CUSTOM_TOOLS_PATH = "$($RtoolsBin.Replace("\", "/"));$($MsysUsrBin.Replace("\", "/"))"
$env:R_LIBS_USER = ""
$env:R_LIBS_SITE = ""
$env:CGV_R_PACKAGE_TYPE = "both"
$env:CGV_CRAN_REPOSITORY = [string]$Lock.cranRepository.url
$env:CGV_BIOCONDUCTOR_VERSION = [string]$Lock.bioconductorVersion
& $Rscript (Join-Path $PSScriptRoot "verify-windows-rtools.R") $RtoolsSoft $MsysRoot ([string]$Lock.rtools44.version)
if ($LASTEXITCODE -ne 0) { throw "Rtools44 isolation verification failed." }
$InstallPackages = (Join-Path $RepoDir "docker\install_packages.R").Replace("\", "/").Replace("'", "\\'")
& $Rscript -e ".libPaths(.Library); source('$InstallPackages')"
if ($LASTEXITCODE -ne 0) { throw "R package installation failed." }

$MmanInput = Convert-ToMsysPath $MmanPackage
& $Pacman -U --noconfirm $MmanInput
if ($LASTEXITCODE -ne 0) { throw "Locked mman-win32 package installation failed." }

$BuildLastz = Convert-ToMsysPath (Join-Path $PSScriptRoot "build-lastz-windows.sh")
$LastzInput = Convert-ToMsysPath $LastzArchive
$LastzOutput = Convert-ToMsysPath (Join-Path $RuntimeRoot "bin\lastz.exe")
& $Bash -lc "/usr/bin/bash '$BuildLastz' '$LastzInput' '$LastzOutput'"
if ($LASTEXITCODE -ne 0) { throw "LASTZ Windows build failed." }

& node (Join-Path $PSScriptRoot "prune-runtime.js") "win32-x64"
if ($LASTEXITCODE -ne 0) { throw "Runtime pruning failed." }

$RuntimeManifest = Join-Path $RuntimeRoot "cgv-runtime-manifest.json"
& $Rscript (Join-Path $PSScriptRoot "verify-runtime-lock.R") $LockFile $RuntimeManifest
if ($LASTEXITCODE -ne 0) { throw "Runtime lock verification failed." }

& node (Join-Path $PSScriptRoot "verify-desktop-runtime.js")
if ($LASTEXITCODE -ne 0) { throw "Desktop runtime verification failed." }

Write-Host "Windows runtime written to $RuntimeRoot"
