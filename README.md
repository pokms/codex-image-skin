# Codex Image Skin

Turn a local image into a reversible visual skin for the Windows Codex desktop app.

`Codex Image Skin` uses a local image to generate a color palette, a home-screen hero, and a restrained native UI treatment. It injects only into the running renderer through a loopback Chromium DevTools Protocol connection. It does not edit `app.asar`, WindowsApps, the official executable, threads, authentication, or plugins.

> English summary: a Windows Codex skill that derives a local, reversible desktop theme from a user-owned image while keeping the real Codex controls interactive.

## What It Does

- Converts a local PNG, JPEG, or BMP into a standard local PNG asset.
- Samples the image to create a readable accent, ink, surface, and hero-overlay palette.
- Keeps the actual Codex sidebar, suggestion cards, project selector, and composer interactive.
- Starts an injection daemon that survives renderer reloads while Codex is running.
- Captures a verification screenshot and supports live removal plus base-theme rollback.

## Requirements

- Windows 10 or Windows 11
- Store-installed Codex package (`OpenAI.Codex`)
- Node.js 18 or later
- Windows PowerShell 5.1 or PowerShell 7
- A local PNG, JPEG, or BMP you are allowed to use

The skill does not download images or publish them. You are responsible for ensuring you have the right to use the image.

## Install

Clone this repository and copy the nested skill folder into Codex's personal skill directory:

```powershell
git clone https://github.com/pokms/codex-image-skin.git
$skillRoot = Join-Path $HOME '.codex\skills\codex-image-skin'
Copy-Item -LiteralPath '.\codex-image-skin\codex-image-skin' -Destination $skillRoot -Recurse -Force
```

Restart Codex or start a new task after copying the folder so the new skill can be discovered.

## Create a Theme from an Image

Use a wide image when possible. Keep a calmer or darker area on the left if you want the native home text to remain especially clear. See [image guidelines](codex-image-skin/references/image-guidelines.md) for crop details.

```powershell
$skillRoot = Join-Path $HOME '.codex\skills\codex-image-skin'
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$skillRoot\scripts\generate-image-theme.ps1" `
  -ImagePath 'C:\Pictures\my-theme.png' `
  -SkillRoot $skillRoot `
  -ThemeName 'My Codex Theme'
```

This creates these local-only files under `assets/`:

- `theme-reference.png`
- `theme.generated.css`
- `theme.generated.json`
- timestamped image backups after a replacement

## Apply and Verify

Install the matching base colors once:

```powershell
$skillRoot = Join-Path $HOME '.codex\skills\codex-image-skin'
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$skillRoot\scripts\install-image-skin.ps1"
```

Start Codex with the local skin:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$skillRoot\scripts\start-image-skin.ps1"
```

If Codex is already running without the selected debug port, close it first. Use `-RestartExisting` only when you explicitly want the script to restart the open Codex instance.

Capture evidence after launch:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$skillRoot\scripts\verify-image-skin.ps1" `
  -ScreenshotPath "$HOME\Desktop\codex-image-skin-verify.png"
```

The verification result should report the injected style, decorative chrome with `pointer-events: none`, a native composer, a native sidebar, and no document overflow. Check both the new-task home screen and a normal task before treating the result as complete.

## Restore

Remove the live skin while keeping the generated local theme files:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$skillRoot\scripts\restore-image-skin.ps1"
```

Restore the base Codex appearance configuration as well:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$skillRoot\scripts\restore-image-skin.ps1" -RestoreBaseTheme
```

Add `-Uninstall` to remove the created launch and restore shortcuts.

## Safety Boundaries

- The CDP endpoint is limited to `127.0.0.1`.
- Official program files, WindowsApps, `app.asar`, authentication, threads, plugins, and user data are left untouched.
- Images are placed only in the real hero/crop regions. The skill never overlays a complete screenshot over the app or replaces native controls.
- Decorative DOM cannot receive pointer events.
- User images, generated CSS/JSON, screenshots, logs, and config backups are ignored by Git.

## Troubleshooting

| Symptom | Resolution |
| --- | --- |
| `OpenAI.Codex Store package is not installed` | Install the official Windows Codex application, then run the start script again. |
| `Theme asset not found` | Run `generate-image-theme.ps1` before install or launch. |
| Codex is already running without debugging | Close it, or rerun the start script with `-RestartExisting` after confirming the restart. |
| Theme disappears after closing Codex | Launch Codex through the `Codex Image Skin` shortcut or rerun the start script; the injector is a runtime process. |
| Image change does not appear | Regenerate the theme and rerun the start script. The renderer revokes the previous image object URL during reinjection. |

## Contributing

Keep the project generic. Do not contribute celebrity images, screenshots containing private data, copied user artwork, generated local assets, or edits that patch official Codex installation files. Run the PowerShell generation test, Node syntax checks, and the Skill validator before opening a pull request.

## License

Released under the [MIT License](LICENSE).
