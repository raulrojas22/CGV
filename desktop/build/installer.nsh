!macro customInstallMode
  ; CGV Desktop is intentionally current-user only. This keeps the assisted
  ; directory/license pages while skipping the per-machine elevation choice.
  StrCpy $isForceCurrentInstall "1"
!macroend

!macro customCheckAppRunning
  ; electron-builder 26.11.1 checks Win32_Process.Path, but the CIM property
  ; exposed by Windows is ExecutablePath. Close the Electron process tree so
  ; the bundled R/Shiny child cannot keep runtime files locked during reinstall.
  DetailPrint "Closing ${PRODUCT_NAME} and its bundled runtime..."
  nsExec::ExecToLog `"$CmdPath" /C taskkill /IM "${APP_EXECUTABLE_FILENAME}" /T /F`
  Pop $0
  Sleep 1000

  ; Also remove an orphaned bundled process left by an earlier abnormal exit.
  ; The path guard ensures unrelated R installations are never touched.
  nsExec::ExecToLog `"$PowerShellPath" -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "Get-CimInstance -ClassName Win32_Process | Where-Object { $$_.ExecutablePath -and $$_.ExecutablePath.StartsWith('$INSTDIR', [System.StringComparison]::OrdinalIgnoreCase) } | ForEach-Object { Stop-Process -Id $$_.ProcessId -Force -ErrorAction SilentlyContinue }"`
  Pop $0
  Sleep 500
!macroend
