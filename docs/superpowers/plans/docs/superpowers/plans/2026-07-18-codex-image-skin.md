# Codex Image Skin Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build and publish a generic Windows Codex skill that creates a reversible theme from a local image without publishing personal artwork or modifying official Codex files.

**Architecture:** The nested `codex-image-skin` directory is the installable skill. A deterministic PowerShell generator converts the user's image to a standard PNG, derives a palette, writes CSS plus JSON metadata, and the CDP injector combines generic layout CSS with the generated CSS at runtime.

**Tech Stack:** Windows PowerShell with System.Drawing, Node.js 24 WebSocket/CDP, plain CSS/JavaScript, Git, GitHub.

---

### Task 1: Establish a skill-usage baseline before authoring guidance

**Files:**
- Create: `tests/skill-eval/baseline.md`
- Test: the public skill workflow before `SKILL.md` exists

- [ ] **Step 1: Run a fresh agent without the new skill**

Use a fresh subagent and provide only this user request:

```text
Create a reusable public Codex skill that accepts a local user image, derives a safe visual palette, applies a reversible Windows Codex desktop skin through CDP, and prepares the project for GitHub. Do not publish personal artwork.
```

Record its raw response in `tests/skill-eval/baseline.md`. Mark whether it omits any of these requirements: preserve native controls, avoid `app.asar`/WindowsApps changes, keep CDP loopback-only, ask before restarting Codex, exclude user artwork from Git, verify with a screenshot, and provide live restore.

- [ ] **Step 2: Derive explicit guidance from the baseline**

Add the observed omissions as concrete guardrails in `codex-image-skin/SKILL.md`; do not rely on generic statements such as "be safe". The final workflow must require image generation before launch, screenshot verification after launch, and restore before removing persistent configuration.

### Task 2: Define the generator contract with a failing test

**Files:**
- Create: `tests/test-generate-image-theme.ps1`
- Create: `tests/fixtures/.gitkeep`
- Test: `codex-image-skin/scripts/generate-image-theme.ps1`

- [ ] **Step 1: Create the contract test before the generator exists**

Write `tests/test-generate-image-theme.ps1` with this behavior:

```powershell
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$skill = Join-Path $repo 'codex-image-skin'
$generator = Join-Path $skill 'scripts\generate-image-theme.ps1'
$sandbox = Join-Path $env:TEMP ('codex-image-skin-test-' + [guid]::NewGuid())
$input = Join-Path $sandbox 'light-cool.png'
$output = Join-Path $sandbox 'skill'

New-Item -ItemType Directory -Force -Path $sandbox, $output | Out-Null
Add-Type -AssemblyName System.Drawing
$bitmap = New-Object System.Drawing.Bitmap 8, 8
for ($x = 0; $x -lt 8; $x++) { for ($y = 0; $y -lt 8; $y++) { $bitmap.SetPixel($x, $y, [System.Drawing.Color]::FromArgb(255, 122, 184, 239)) } }
$bitmap.Save($input, [System.Drawing.Imaging.ImageFormat]::Png)
$bitmap.Dispose()

try {
  if (-not (Test-Path -LiteralPath $generator)) { throw "Missing generator: $generator" }
  & $generator -ImagePath $input -SkillRoot $output -ThemeName 'Test Theme'
  if ($LASTEXITCODE -ne 0) { throw "Generator exited with $LASTEXITCODE" }
  $css = Get-Content (Join-Path $output 'assets\theme.generated.css') -Raw
  $metadata = Get-Content (Join-Path $output 'assets\theme.generated.json') -Raw | ConvertFrom-Json
  if ($css -notmatch '--image-skin-accent: #[0-9A-Fa-f]{6};') { throw 'Generated CSS has no accent token.' }
  if ($css -match '__[A-Z_]+__') { throw 'Generated CSS contains an unresolved placeholder.' }
  if ($metadata.themeName -ne 'Test Theme' -or -not $metadata.accent) { throw 'Generated JSON has no usable palette.' }
  if (-not (Test-Path (Join-Path $output 'assets\theme-reference.png'))) { throw 'Generator did not normalize the image to PNG.' }
  Write-Host 'PASS: generator emits image, CSS, and palette metadata.'
} finally {
  if (Test-Path $sandbox) { Remove-Item -LiteralPath $sandbox -Recurse -Force }
}
```

- [ ] **Step 2: Run the test and confirm RED**

Run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File 'C:\Users\dell\Documents\codex-image-skin\tests\test-generate-image-theme.ps1'
```

Expected: a non-zero exit with `Missing generator`, proving the test exercises the requested behavior rather than passing accidentally.

### Task 3: Initialize the installable skill package

**Files:**
- Create: `codex-image-skin/SKILL.md`
- Create: `codex-image-skin/agents/openai.yaml`
- Create: `codex-image-skin/assets/`
- Create: `codex-image-skin/scripts/`
- Create: `codex-image-skin/references/`

- [ ] **Step 1: Read the skill interface metadata reference**

Read `C:\Users\dell\.codex\skills\.system\skill-creator\references\openai_yaml.md` before choosing interface strings.

- [ ] **Step 2: Initialize the package using the supplied initializer**

Run the bundled Python runtime and initializer:

```powershell
& 'C:\Users\dell\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe' 'C:\Users\dell\.codex\skills\.system\skill-creator\scripts\init_skill.py' codex-image-skin --path 'C:\Users\dell\Documents\codex-image-skin' --resources scripts,references,assets --interface 'display_name=Codex Image Skin' --interface 'short_description=Generate a reversible Codex theme from a local image' --interface 'default_prompt=Use $codex-image-skin to turn my local image into a safe, reversible Codex desktop theme.'
```

Expected: a nested `codex-image-skin` directory with `SKILL.md`, `agents/openai.yaml`, and the requested resource directories.

- [ ] **Step 3: Replace the generated SKILL.md with concise trigger and workflow guidance**

Use this frontmatter:

```yaml
---
name: codex-image-skin
description: Use when a user wants to turn a local image into a custom visual skin for the Windows Codex desktop app, asks to generate, apply, preview, update, verify, or restore an image-derived Codex theme, or needs a reversible alternative to editing app.asar.
---
```

Document the required sequence: validate local image, generate palette, install base theme, launch through loopback CDP, verify screenshot, and restore. Require confirmation before `-RestartExisting`; forbid publishing user artwork, changing WindowsApps, or faking the UI with a full-window screenshot.

### Task 4: Implement and validate image-to-palette generation

**Files:**
- Create: `codex-image-skin/scripts/generate-image-theme.ps1`
- Create: `codex-image-skin/assets/theme.generated.css`
- Create: `codex-image-skin/assets/theme.generated.json`
- Test: `tests/test-generate-image-theme.ps1`

- [ ] **Step 1: Implement only the generator behavior required by the failing test**

Create `generate-image-theme.ps1` with parameters:

```powershell
[CmdletBinding()]
param(
  [Parameter(Mandatory)][string]$ImagePath,
  [Parameter(Mandatory)][string]$SkillRoot,
  [ValidatePattern('^[A-Za-z0-9 _-]{1,64}$')][string]$ThemeName = 'Image Theme'
)
```

Implement these functions:

```powershell
function Convert-RgbToHex([int]$Red, [int]$Green, [int]$Blue) { '#{0:X2}{1:X2}{2:X2}' -f $Red, $Green, $Blue }
function Get-Luminance([int]$Red, [int]$Green, [int]$Blue) { (0.2126 * $Red + 0.7152 * $Green + 0.0722 * $Blue) / 255 }
function Clamp([double]$Value, [double]$Min, [double]$Max) { [Math]::Max($Min, [Math]::Min($Max, $Value)) }
```

Load the image through `System.Drawing.Bitmap`, sample a maximum 64-by-64 grid while skipping alpha-zero pixels, average the sampled RGB values, and save the original image as PNG to `assets/theme-reference.png`. Write the computed values with this output pattern:

```powershell
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
  overlay = $overlay
  generatedAt = (Get-Date).ToUniversalTime().ToString('o')
} | ConvertTo-Json
Set-Content -LiteralPath (Join-Path $assets 'theme.generated.css') -Value $css -Encoding utf8
Set-Content -LiteralPath (Join-Path $assets 'theme.generated.json') -Value $metadata -Encoding utf8
```

Choose dark ink for light images and white ink for dark images. Back up any existing `theme-reference.png` under `assets/backups/` before replacing it.

- [ ] **Step 2: Run the test and confirm GREEN**

Run the Task 2 command. Expected: `PASS: generator emits image, CSS, and palette metadata.`

- [ ] **Step 3: Cover three image conditions**

Extend `tests/test-generate-image-theme.ps1` to generate light-cool `(122,184,239)`, dark-warm `(66,34,92)`, and high-contrast checkerboard fixtures. Invoke the generator three times and assert the three JSON files have valid hex accent/ink/surface fields and each CSS file has no unresolved placeholders.

### Task 5: Build the generic runtime and recovery workflow

**Files:**
- Create: `codex-image-skin/assets/base-skin.css`
- Create: `codex-image-skin/assets/renderer-inject.js`
- Create: `codex-image-skin/scripts/injector.mjs`
- Create: `codex-image-skin/scripts/install-image-skin.ps1`
- Create: `codex-image-skin/scripts/start-image-skin.ps1`
- Create: `codex-image-skin/scripts/verify-image-skin.ps1`
- Create: `codex-image-skin/scripts/restore-image-skin.ps1`
- Create: `codex-image-skin/references/image-guidelines.md`
- Create: `codex-image-skin/references/qa-checklist.md`

- [ ] **Step 1: Port the existing CDP launcher without personal branding**

Use a previously verified generic CDP launcher as the behavioral source. Read `assets/base-skin.css`, `assets/theme.generated.css`, `assets/renderer-inject.js`, and `assets/theme-reference.png` in `loadPayload()`, concatenate the CSS strings, and retain loopback-only target discovery:

```javascript
const [baseCss, generatedCss, template, art] = await Promise.all([
  fs.readFile(path.join(root, "assets", "base-skin.css"), "utf8"),
  fs.readFile(path.join(root, "assets", "theme.generated.css"), "utf8"),
  fs.readFile(path.join(root, "assets", "renderer-inject.js"), "utf8"),
  fs.readFile(path.join(root, "assets", "theme-reference.png")),
]);
const css = `${baseCss}\n${generatedCss}`;
```

Make injection idempotent. Disconnect old observers and timers, revoke any previous object URL, create a new artwork object URL, then set `--image-skin-art`. Decorative DOM must use `pointer-events: none`; native elements remain untouched and interactive.

- [ ] **Step 2: Implement generic CSS and DOM**

Create a hero that uses the generated image plus the generated overlay:

```css
.image-skin-home .image-skin-hero {
  background-image: linear-gradient(90deg, var(--image-skin-overlay) 0%, transparent 72%), var(--image-skin-art);
  background-repeat: no-repeat;
  background-size: 100% 100%, cover;
  background-position: center, var(--image-skin-hero-position);
}
```

Use only generic text such as `Codex Image Theme`. Do not draw duplicate cards, project selectors, input fields, or full-window screenshot overlays.

- [ ] **Step 3: Retain install, start, verify, and restore contracts**

Preserve the existing safe behavior: use `Get-AppxPackage OpenAI.Codex` dynamically, start `ChatGPT.exe` with `--remote-debugging-port`, record `%LOCALAPPDATA%\CodexImageSkin\state.json`, and offer `-RestartExisting` only when approved. Read generated JSON in the installer to set light chrome `accent`, `ink`, and `surface`. Keep restore responsible for live CSS/DOM removal and optional original-config recovery.

- [ ] **Step 4: Validate static runtime files**

Run:

```powershell
node --check 'C:\Users\dell\Documents\codex-image-skin\codex-image-skin\scripts\injector.mjs'
node --check 'C:\Users\dell\Documents\codex-image-skin\codex-image-skin\assets\renderer-inject.js'
& 'C:\Users\dell\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe' 'C:\Users\dell\.codex\skills\.system\skill-creator\scripts\quick_validate.py' 'C:\Users\dell\Documents\codex-image-skin\codex-image-skin'
```

Expected: both Node checks exit zero and `quick_validate.py` reports a valid skill.

- [ ] **Step 5: Re-run the baseline request with the skill installed**

Use a fresh subagent with the same Task 1 request and the created `codex-image-skin` package. Record the result in `tests/skill-eval/green.md`. Expected: it follows the complete safe workflow, does not propose publishing user artwork, and requests restart authorization before using `-RestartExisting`.

### Task 6: Document, package, and publish

**Files:**
- Create: `README.md`
- Create: `LICENSE`
- Create: `.gitignore`
- Modify: `docs/superpowers/specs/2026-07-18-codex-image-skin-design.md`
- Modify: `docs/superpowers/plans/2026-07-18-codex-image-skin.md`

- [ ] **Step 1: Write the public README**

Document the exact installation destination `%USERPROFILE%\.codex\skills\codex-image-skin`, local image requirements, generation command, safe launch command, screenshot verification command, restore command, runtime limitations, and the rule that users must own or be allowed to use uploaded images. Include a concise English summary and never claim guaranteed reviews or support for untested Codex versions.

- [ ] **Step 2: Add publication-safe exclusions and MIT license**

Write `.gitignore` with:

```gitignore
codex-image-skin/assets/theme-reference.png
codex-image-skin/assets/backups/
codex-image-skin/assets/theme.generated.css
codex-image-skin/assets/theme.generated.json
*.log
*.png
!tests/fixtures/.gitkeep
```

Write the standard MIT license with `Copyright (c) 2026 pokms`.

- [ ] **Step 3: Initialize Git and commit the verified release**

Run:

```powershell
git init -b main 'C:\Users\dell\Documents\codex-image-skin'
git -C 'C:\Users\dell\Documents\codex-image-skin' add .
git -C 'C:\Users\dell\Documents\codex-image-skin' commit -m 'feat: add image-driven Codex skin skill'
```

Before committing, confirm `git config user.name` and `git config user.email` resolve to the user's intended identity. If either is empty, stop and request values instead of inventing them.

- [ ] **Step 4: Create and push the public repository**

Create the public repository `pokms/codex-image-skin` through the user's authenticated GitHub browser session, without adding a README or license remotely. Then run:

```powershell
git -C 'C:\Users\dell\Documents\codex-image-skin' remote add origin 'https://github.com/pokms/codex-image-skin.git'
git -C 'C:\Users\dell\Documents\codex-image-skin' push -u origin main
```

Expected: GitHub reports the repository as public and the default branch contains the README, `codex-image-skin` package, test, license, and no excluded user artifacts.

- [ ] **Step 5: Verify the published tree**

Run:

```powershell
git ls-remote --symref 'https://github.com/pokms/codex-image-skin.git' HEAD
```

Expected: `HEAD` points to `refs/heads/main`. Open the public README in the authenticated browser and verify the rendered installation and safety sections are present.
