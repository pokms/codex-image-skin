---
name: codex-image-skin
description: Use when a user wants to turn a local image into a custom visual skin for the Windows Codex desktop app, asks to generate, apply, preview, update, verify, or restore an image-derived Codex theme, or needs a reversible alternative to editing app.asar.
---

# Codex Image Skin

Generate a local, reversible Codex desktop theme from a user-supplied image. Preserve the official package and real Codex controls.

## Workflow

1. Confirm Windows, Node.js, and the Store-installed `OpenAI.Codex` package are available. Stop before launch if the prerequisites are absent.
2. Confirm the user owns or is allowed to use the local image. Do not copy user images, generated assets, screenshots, logs, or local configuration into Git.
3. Generate the image asset and palette before installation. The generated ink and surface colors must meet a 4.5:1 WCAG contrast ratio:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$SkillRoot\scripts\generate-image-theme.ps1" -ImagePath "C:\path\to\image.png" -SkillRoot $SkillRoot -ThemeName "My Codex Theme"
```

4. Run `scripts\install-image-skin.ps1` to back up the user's existing Codex base appearance and create launch/restore shortcuts.
5. Start with `scripts\start-image-skin.ps1`. If Codex is already open without the selected debug port, ask for explicit permission before adding `-RestartExisting`.
6. Run `scripts\verify-image-skin.ps1 -ScreenshotPath <absolute-path>` and inspect both the new-task home screen and a normal task. Treat a missing hero, native composer, sidebar, injection marker, or responsive card layout as failure.
7. Use `scripts\restore-image-skin.ps1` for live removal. Add `-RestoreBaseTheme` only when the user wants the pre-install appearance configuration restored.

## Guardrails

- Never modify `app.asar`, WindowsApps, the official executable, package ownership, authentication, user threads, plugins, or user data.
- Bind CDP only to `127.0.0.1`.
- Keep the uploaded image in the real home hero and optional decorative crop only. Never use a full-window image overlay or create fake controls.
- Keep every decorative layer `pointer-events: none`. Real cards, navigation, project selection, composer, and buttons must remain above it and clickable.
- Do not publish user images, generated CSS/JSON, screenshots, logs, state files, or config backups.
- Revoke the old artwork object URL whenever reinjecting a changed image so the renderer cannot retain a stale image.

## Resources

- `scripts/generate-image-theme.ps1`: normalizes the image, derives a palette, and writes generated local theme assets.
- `scripts/injector.mjs`: connects to the loopback CDP endpoint, injects, verifies, screenshots, and removes the live skin.
- `scripts/install-image-skin.ps1`, `start-image-skin.ps1`, `verify-image-skin.ps1`, `restore-image-skin.ps1`: install, launch, verify, and rollback entry points.
- `references/image-guidelines.md`: source image and crop guidance.
- `references/qa-checklist.md`: visual and functional signoff requirements.
