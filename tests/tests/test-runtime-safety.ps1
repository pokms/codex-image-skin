[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$installScript = Join-Path $repo 'codex-image-skin\scripts\install-image-skin.ps1'
$startScript = Join-Path $repo 'codex-image-skin\scripts\start-image-skin.ps1'

function Assert-RuntimeSafety([string]$InstallSource, [string]$StartSource) {
  $shortcutArguments = [regex]::Match($InstallSource, '(?m)^\s*\$shortcut\.Arguments\s*=\s*(?<value>.+)$')
  if (-not $shortcutArguments.Success) {
    throw 'Install script does not define launch shortcut arguments.'
  }
  if ($shortcutArguments.Groups['value'].Value -match '(?i)-RestartExisting') {
    throw 'Launch shortcut restarts Codex without explicit user approval.'
  }
  if ($StartSource -notmatch '--remote-debugging-address=127\.0\.0\.1') {
    throw 'Codex launch arguments do not explicitly bind CDP to 127.0.0.1.'
  }
}

$installSource = Get-Content -LiteralPath $installScript -Raw
$startSource = Get-Content -LiteralPath $startScript -Raw
Assert-RuntimeSafety $installSource $startSource

$unsafeShortcut = $installSource -replace '(?m)^(\s*\$shortcut\.Arguments\s*=\s*.+)$', '$1 -RestartExisting'
try {
  Assert-RuntimeSafety $unsafeShortcut $startSource
  throw 'Runtime safety assertion did not reject an unsafe restart shortcut.'
} catch {
  if ($_.Exception.Message -notmatch 'restarts Codex without explicit user approval') { throw }
}

$unsafeBinding = $startSource -replace '--remote-debugging-address=127\.0\.0\.1', ''
try {
  Assert-RuntimeSafety $installSource $unsafeBinding
  throw 'Runtime safety assertion did not reject a non-loopback CDP launch.'
} catch {
  if ($_.Exception.Message -notmatch 'do not explicitly bind CDP to 127.0.0.1') { throw }
}

Write-Host 'PASS: launch shortcuts require explicit restart approval and CDP binds to loopback.'
