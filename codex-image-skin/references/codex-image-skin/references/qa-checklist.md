# QA Checklist

## Static

- `generate-image-theme.ps1` produces `theme-reference.png`, `theme.generated.css`, and `theme.generated.json`.
- Generated colors are valid six-digit hex values, no template placeholders remain, and ink/surface contrast is at least 4.5:1.
- `node --check` passes for the injector and renderer scripts.

## Runtime

- The home screen has an image-derived hero, native suggestion cards, a project selector, sidebar, and composer.
- Decorative chrome has `pointer-events: none`.
- A normal task has readable messages and a usable composer.
- Verification reports no horizontal overflow and two to four responsive suggestion cards when present.
- Reload reinjects the image skin while the injector daemon runs.
- Restore removes the marker, CSS, and decorative DOM; a subsequent start reapplies the skin.

## Safety

- The CDP endpoint uses `127.0.0.1` only.
- No WindowsApps, `app.asar`, official executable, authentication, or user content is modified.
- No user images, generated assets, logs, screenshots, or configuration backups are staged for Git.
