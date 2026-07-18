[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$skill = Join-Path $repo 'codex-image-skin'
$generator = Join-Path $skill 'scripts\generate-image-theme.ps1'
$sandbox = Join-Path $env:TEMP ('codex-image-skin-test-' + [guid]::NewGuid())
$input = Join-Path $sandbox 'light-cool.png'
$output = Join-Path $sandbox 'skill'

New-Item -ItemType Directory -Force -Path $sandbox, $output | Out-Null
Add-Type -AssemblyName System.Drawing
function New-SolidFixture([string]$Path, [int]$Red, [int]$Green, [int]$Blue) {
  $bitmap = New-Object System.Drawing.Bitmap 8, 8
  try {
    for ($x = 0; $x -lt 8; $x++) {
      for ($y = 0; $y -lt 8; $y++) {
        $bitmap.SetPixel($x, $y, [System.Drawing.Color]::FromArgb(255, $Red, $Green, $Blue))
      }
    }
    $bitmap.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
  } finally {
    $bitmap.Dispose()
  }
}

function New-CheckerboardFixture([string]$Path) {
  $bitmap = New-Object System.Drawing.Bitmap 8, 8
  try {
    for ($x = 0; $x -lt 8; $x++) {
      for ($y = 0; $y -lt 8; $y++) {
        $color = if (($x + $y) % 2 -eq 0) { [System.Drawing.Color]::FromArgb(255, 28, 52, 82) } else { [System.Drawing.Color]::FromArgb(255, 219, 239, 255) }
        $bitmap.SetPixel($x, $y, $color)
      }
    }
    $bitmap.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
  } finally {
    $bitmap.Dispose()
  }
}

function Convert-HexToRelativeLuminance([string]$Color) {
  if ($Color -notmatch '^#(?<red>[0-9A-Fa-f]{2})(?<green>[0-9A-Fa-f]{2})(?<blue>[0-9A-Fa-f]{2})$') {
    throw "Expected a six-digit hex color, got: $Color"
  }

  $channels = @(
    ([Convert]::ToInt32($Matches.red, 16) / 255.0),
    ([Convert]::ToInt32($Matches.green, 16) / 255.0),
    ([Convert]::ToInt32($Matches.blue, 16) / 255.0)
  ) | ForEach-Object {
    if ($_ -le 0.04045) { $_ / 12.92 } else { [Math]::Pow((($_ + 0.055) / 1.055), 2.4) }
  }

  (0.2126 * $channels[0]) + (0.7152 * $channels[1]) + (0.0722 * $channels[2])
}

function Get-ContrastRatio([string]$First, [string]$Second) {
  $firstLuminance = Convert-HexToRelativeLuminance $First
  $secondLuminance = Convert-HexToRelativeLuminance $Second
  ([Math]::Max($firstLuminance, $secondLuminance) + 0.05) / ([Math]::Min($firstLuminance, $secondLuminance) + 0.05)
}

New-SolidFixture $input 122 184 239

try {
  if (-not (Test-Path -LiteralPath $generator)) {
    throw "Missing generator: $generator"
  }

  & $generator -ImagePath $input -SkillRoot $output -ThemeName 'Test Theme'
  if ($null -ne $LASTEXITCODE -and $LASTEXITCODE -ne 0) {
    throw "Generator exited with $LASTEXITCODE"
  }

  $css = Get-Content (Join-Path $output 'assets\theme.generated.css') -Raw
  $metadata = Get-Content (Join-Path $output 'assets\theme.generated.json') -Raw | ConvertFrom-Json
  if ($css -notmatch '--image-skin-accent: #[0-9A-Fa-f]{6};') {
    throw 'Generated CSS has no accent token.'
  }
  if ($css -match '__[A-Z_]+__') {
    throw 'Generated CSS contains an unresolved placeholder.'
  }
  if ($metadata.themeName -ne 'Test Theme' -or -not $metadata.accent) {
    throw 'Generated JSON has no usable palette.'
  }
  if (-not (Test-Path (Join-Path $output 'assets\theme-reference.png'))) {
    throw 'Generator did not normalize the image to PNG.'
  }
  $lightContrastRatio = Get-ContrastRatio $metadata.ink $metadata.surface
  if ($lightContrastRatio -lt 4.5) {
    throw "Insufficient ink/surface contrast for light-cool: $lightContrastRatio"
  }
  if ($null -eq $metadata.contrastRatio -or [double]$metadata.contrastRatio -lt 4.5) {
    throw 'Generated metadata has no WCAG contrast ratio for light-cool.'
  }
  if ([Math]::Abs(([double]$metadata.contrastRatio) - $lightContrastRatio) -gt 0.01) {
    throw 'Generated contrast ratio does not match the light-cool ink/surface palette.'
  }

  $cases = @(
    @{ name = 'dark-warm'; create = { param($path) New-SolidFixture $path 66 34 92 } },
    @{ name = 'high-contrast'; create = { param($path) New-CheckerboardFixture $path } }
  )
  foreach ($case in $cases) {
    $caseInput = Join-Path $sandbox "$($case.name).png"
    $caseOutput = Join-Path $sandbox "$($case.name)-output"
    New-Item -ItemType Directory -Force -Path $caseOutput | Out-Null
    & $case.create $caseInput
    & $generator -ImagePath $caseInput -SkillRoot $caseOutput -ThemeName $case.name
    $caseCss = Get-Content (Join-Path $caseOutput 'assets\theme.generated.css') -Raw
    $caseMetadata = Get-Content (Join-Path $caseOutput 'assets\theme.generated.json') -Raw | ConvertFrom-Json
    if ($caseMetadata.accent -notmatch '^#[0-9A-F]{6}$' -or $caseMetadata.ink -notmatch '^#[0-9A-F]{6}$' -or $caseMetadata.surface -notmatch '^#[0-9A-F]{6}$') {
      throw "Invalid palette for $($case.name)."
    }
    if ($caseCss -match '__[A-Z_]+__') { throw "Unresolved placeholder for $($case.name)." }
    $contrastRatio = Get-ContrastRatio $caseMetadata.ink $caseMetadata.surface
    if ($contrastRatio -lt 4.5) { throw "Insufficient ink/surface contrast for $($case.name): $contrastRatio" }
    if ($null -eq $caseMetadata.contrastRatio -or [double]$caseMetadata.contrastRatio -lt 4.5) {
      throw "Generated metadata has no WCAG contrast ratio for $($case.name)."
    }
    if ([Math]::Abs(([double]$caseMetadata.contrastRatio) - $contrastRatio) -gt 0.01) {
      throw "Generated contrast ratio does not match the ink/surface palette for $($case.name)."
    }
  }

  Write-Host 'PASS: generator emits image, CSS, and WCAG-compliant palette metadata for three synthetic fixtures.'
} finally {
  if (Test-Path $sandbox) {
    Remove-Item -LiteralPath $sandbox -Recurse -Force
  }
}
