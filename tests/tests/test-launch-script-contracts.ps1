[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$installScript = Join-Path $repo 'codex-image-skin\scripts\install-image-skin.ps1'
$startScript = Join-Path $repo 'codex-image-skin\scripts\start-image-skin.ps1'

foreach ($path in @($installScript, $startScript)) {
  if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Missing script: $path" }
}

$shortcutArguments = Select-String -LiteralPath $installScript -Pattern '^\s*\$shortcut\.Arguments\s*=' | Select-Object -ExpandProperty Line
if ($shortcutArguments.Count -ne 1) { throw 'Expected exactly one Codex Image Skin launch shortcut argument declaration.' }
if ($shortcutArguments -match '(?i)-RestartExisting') {
  throw 'The launch shortcut must not restart an open Codex instance by default.'
}

$startContent = Get-Content -LiteralPath $startScript -Raw
if ($startContent -notmatch '(?s)\$arguments\s*=\s*@\(\s*"--remote-debugging-port=\$Port"\s*,\s*"--remote-debugging-address=127\.0\.0\.1"\s*\)') {
  throw 'Codex must launch with --remote-debugging-address=127.0.0.1.'
}

Write-Host 'PASS: launch shortcuts require explicit restart consent and CDP binds to loopback.'
