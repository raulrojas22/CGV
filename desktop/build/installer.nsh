!macro customInstallMode
  ; CGV Desktop is intentionally current-user only. This keeps the assisted
  ; directory/license pages while skipping the per-machine elevation choice.
  StrCpy $isForceCurrentInstall "1"
!macroend
