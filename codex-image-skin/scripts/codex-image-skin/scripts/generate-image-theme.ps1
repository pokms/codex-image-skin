[CmdletBinding()]
param(
  [Parameter(Mandatory)]
  [ValidateNotNullOrEmpty()]
  [string]$ImagePath,

  [Parameter(Mandatory)]
  [ValidateNotNullOrEmpty()]
  [string]$SkillRoot,

  [ValidatePattern('^[A-Za-z0-9 _-]{1,64}$')]
  [string]$ThemeName = 'Image Theme'
)

$ErrorActionPreference = 'Stop'

function Convert-RgbToHex([int]$Red, [int]$Green, [int]$Blue) {
  '#{0:X2}{1:X2}{2:X2}' -f $Red, $Green, $Blue
}

function Convert-SrgbChannelToLinear([int]$Channel) {
  $value = $Channel / 255.0
  if ($value -le 0.04045) { return $value / 12.92 }
  [Math]::Pow((($value + 0.055) / 1.055), 2.4)
}

function Get-RelativeLuminance([int]$Red, [int]$Green, [int]$Blue) {
  (0.2126 * (Convert-SrgbChannelToLinear $Red)) +
  (0.7152 * (Convert-SrgbChannelToLinear $Green)) +
  (0.0722 * (Convert-SrgbChannelToLinear $Blue))
}

function Get-ContrastRatio([int]$FirstRed, [int]$FirstGreen, [int]$FirstBlue, [int]$SecondRed, [int]$SecondGreen, [int]$SecondBlue) {
  $firstLuminance = Get-RelativeLuminance $FirstRed $FirstGreen $FirstBlue
  $secondLuminance = Get-RelativeLuminance $SecondRed $SecondGreen $SecondBlue
  ([Math]::Max($firstLuminance, $secondLuminance) + 0.05) / ([Math]::Min($firstLuminance, $secondLuminance) + 0.05)
}

function Clamp([double]$Value, [double]$Min, [double]$Max) {
  [Math]::Max($Min, [Math]::Min($Max, $Value))
}

function Blend-Channel([int]$From, [int]$To, [double]$Amount) {
  [int][Math]::Round($From + (($To - $From) * $Amount))
}

if (-not (Test-Path -LiteralPath $ImagePath -PathType Leaf)) {
  throw "Image was not found: $ImagePath"
}

Add-Type -AssemblyName System.Drawing

$assets = Join-Path $SkillRoot 'assets'
$backups = Join-Path $assets 'backups'
New-Item -ItemType Directory -Force -Path $assets, $backups | Out-Null

$image = $null
$normalized = $null
try {
  $image = [System.Drawing.Image]::FromFile((Resolve-Path -LiteralPath $ImagePath))
  $bitmap = New-Object System.Drawing.Bitmap $image

  $sampleWidth = [Math]::Min(64, $bitmap.Width)
  $sampleHeight = [Math]::Min(64, $bitmap.Height)
  $stepX = [Math]::Max(1, [int][Math]::Floor($bitmap.Width / $sampleWidth))
  $stepY = [Math]::Max(1, [int][Math]::Floor($bitmap.Height / $sampleHeight))
  $redTotal = 0.0
  $greenTotal = 0.0
  $blueTotal = 0.0
  $weightTotal = 0.0

  for ($x = 0; $x -lt $bitmap.Width; $x += $stepX) {
    for ($y = 0; $y -lt $bitmap.Height; $y += $stepY) {
      $pixel = $bitmap.GetPixel($x, $y)
      if ($pixel.A -eq 0) { continue }

      $maximum = [Math]::Max($pixel.R, [Math]::Max($pixel.G, $pixel.B))
      $minimum = [Math]::Min($pixel.R, [Math]::Min($pixel.G, $pixel.B))
      $saturation = if ($maximum -eq 0) { 0 } else { ($maximum - $minimum) / $maximum }
      $weight = 1 + ($saturation * 0.75)
      $redTotal += $pixel.R * $weight
      $greenTotal += $pixel.G * $weight
      $blueTotal += $pixel.B * $weight
      $weightTotal += $weight
    }
  }

  if ($weightTotal -eq 0) {
    throw 'The image contains no visible pixels.'
  }

  $red = [int][Math]::Round($redTotal / $weightTotal)
  $green = [int][Math]::Round($greenTotal / $weightTotal)
  $blue = [int][Math]::Round($blueTotal / $weightTotal)
  $accent = Convert-RgbToHex $red $green $blue
  $surfaceRed = Blend-Channel $red 255 0.88
  $surfaceGreen = Blend-Channel $green 255 0.88
  $surfaceBlue = Blend-Channel $blue 255 0.88
  $surface = Convert-RgbToHex $surfaceRed $surfaceGreen $surfaceBlue
  $darkInk = @(23, 50, 77)
  $lightInk = @(245, 250, 255)
  $darkContrast = Get-ContrastRatio $darkInk[0] $darkInk[1] $darkInk[2] $surfaceRed $surfaceGreen $surfaceBlue
  $lightContrast = Get-ContrastRatio $lightInk[0] $lightInk[1] $lightInk[2] $surfaceRed $surfaceGreen $surfaceBlue
  if ($darkContrast -ge $lightContrast) {
    $ink = '#17324D'
    $contrastRatio = $darkContrast
  } else {
    $ink = '#F5FAFF'
    $contrastRatio = $lightContrast
  }
  if ($contrastRatio -lt 4.5) {
    throw "Unable to generate an accessible ink/surface pair: $contrastRatio"
  }
  $overlayRed = [int](Clamp ($red * 0.32) 8 76)
  $overlayGreen = [int](Clamp ($green * 0.42) 16 104)
  $overlayBlue = [int](Clamp ($blue * 0.50) 28 138)
  $overlay = "rgba($overlayRed, $overlayGreen, $overlayBlue, .92)"

  $reference = Join-Path $assets 'theme-reference.png'
  if (Test-Path -LiteralPath $reference) {
    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmssfff'
    Copy-Item -LiteralPath $reference -Destination (Join-Path $backups "theme-reference-$timestamp.png") -Force
  }

  $normalized = New-Object System.Drawing.Bitmap $image
  $normalized.Save($reference, [System.Drawing.Imaging.ImageFormat]::Png)

  $css = @"
:root.codex-image-skin {
  --image-skin-accent: $accent;
  --image-skin-ink: $ink;
  --image-skin-surface: $surface;
  --image-skin-overlay: $overlay;
  --image-skin-hero-position: right center;
}
"@
  $metadata = [ordered]@{
    themeName = $ThemeName
    accent = $accent
    ink = $ink
    surface = $surface
    contrastRatio = [Math]::Round($contrastRatio, 4)
    overlay = $overlay
    generatedAt = (Get-Date).ToUniversalTime().ToString('o')
  } | ConvertTo-Json

  Set-Content -LiteralPath (Join-Path $assets 'theme.generated.css') -Value $css -Encoding utf8
  Set-Content -LiteralPath (Join-Path $assets 'theme.generated.json') -Value $metadata -Encoding utf8
  Write-Host "Generated $ThemeName from $ImagePath"
} finally {
  if ($normalized) { $normalized.Dispose() }
  if ($bitmap) { $bitmap.Dispose() }
  if ($image) { $image.Dispose() }
}
