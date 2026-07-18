[CmdletBinding()]
param(
  [int]$Port = 9335,
  [switch]$NoShortcuts
)

$ErrorActionPreference = 'Stop'
$SkillRoot = Split-Path -Parent $PSScriptRoot
$StateRoot = Join-Path $env:LOCALAPPDATA 'CodexImageSkin'
New-Item -ItemType Directory -Force -Path $StateRoot | Out-Null
$ConfigPath = Join-Path $HOME '.codex\config.toml'
$BackupPath = Join-Path $StateRoot 'config.before-image-skin.toml'
if (-not (Test-Path -LiteralPath $ConfigPath)) { throw "Codex config not found: $ConfigPath" }
$ThemePath = Join-Path $SkillRoot 'assets\theme.generated.json'
if (-not (Test-Path -LiteralPath $ThemePath)) { throw "Generated theme metadata not found: $ThemePath. Run generate-image-theme.ps1 first." }
$theme = Get-Content -LiteralPath $ThemePath -Raw | ConvertFrom-Json
foreach ($color in @($theme.accent, $theme.ink, $theme.surface)) {
  if ($color -notmatch '^#[0-9A-Fa-f]{6}$') { throw 'Generated theme metadata contains an invalid color.' }
}
if (-not (Test-Path -LiteralPath $BackupPath)) { Copy-Item -LiteralPath $ConfigPath -Destination $BackupPath }

$content = Get-Content -LiteralPath $ConfigPath -Raw
$desktopMatch = [regex]::Match($content, '(?ms)^\[desktop\]\s*\r?\n(?<body>.*?)(?=^\[|\z)')
if (-not $desktopMatch.Success) {
  $content = $content.TrimEnd() + "`r`n`r`n[desktop]`r`n"
  $desktopMatch = [regex]::Match($content, '(?ms)^\[desktop\]\s*\r?\n(?<body>.*?)(?=^\[|\z)')
}
$body = $desktopMatch.Groups['body'].Value
$settings = [ordered]@{
  appearanceTheme = 'appearanceTheme = "light"'
  appearanceLightCodeThemeId = 'appearanceLightCodeThemeId = "codex"'
  appearanceLightChromeTheme = "appearanceLightChromeTheme = { accent = `"$($theme.accent)`", contrast = 64, fonts = { code = `"Cascadia Code`", ui = `"Microsoft YaHei UI`" }, ink = `"$($theme.ink)`", opaqueWindows = true, semanticColors = { diffAdded = `"#BCE8CF`", diffRemoved = `"#F7C8D8`", skill = `"$($theme.accent)`" }, surface = `"$($theme.surface)`" }"
}
foreach ($key in $settings.Keys) {
  $pattern = "(?m)^$([regex]::Escape($key))\s*=.*$"
  if ([regex]::IsMatch($body, $pattern)) { $body = [regex]::Replace($body, $pattern, $settings[$key]) }
  else { $body = $body.TrimEnd() + "`r`n" + $settings[$key] + "`r`n" }
}
$content = $content.Substring(0, $desktopMatch.Groups['body'].Index) + $body + $content.Substring($desktopMatch.Groups['body'].Index + $desktopMatch.Groups['body'].Length)
Set-Content -LiteralPath $ConfigPath -Value $content -Encoding utf8

if (-not $NoShortcuts) {
  $shell = New-Object -ComObject WScript.Shell
  $desktop = [Environment]::GetFolderPath('Desktop')
  $startMenu = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs'
  $powershell = (Get-Command powershell.exe).Source
  $startScript = Join-Path $PSScriptRoot 'start-image-skin.ps1'
  $restoreScript = Join-Path $PSScriptRoot 'restore-image-skin.ps1'
  foreach ($folder in @($desktop, $startMenu)) {
    $shortcut = $shell.CreateShortcut((Join-Path $folder 'Codex Image Skin.lnk'))
    $shortcut.TargetPath = $powershell
    $shortcut.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$startScript`" -Port $Port"
    $shortcut.WorkingDirectory = $SkillRoot
    $shortcut.Description = 'Launch Codex with the Image-derived full interface skin'
    $shortcut.Save()
  }
  $restore = $shell.CreateShortcut((Join-Path $desktop 'Codex Image Skin - Restore.lnk'))
  $restore.TargetPath = $powershell
  $restore.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$restoreScript`" -Port $Port"
  $restore.WorkingDirectory = $SkillRoot
  $restore.Description = 'Remove the live Codex Image Skin'
  $restore.Save()
}

Write-Host 'Codex Image Skin installed. Launch it with the created shortcut or start-image-skin.ps1.'
