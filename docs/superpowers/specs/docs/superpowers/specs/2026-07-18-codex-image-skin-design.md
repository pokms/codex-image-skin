# Codex Image Skin Design

## Goal

Publish a reusable Windows Codex skill that turns a user-supplied image into a reversible desktop skin. The public package must contain no personal, celebrity, or user-uploaded artwork.

## Public Repository Layout

```text
codex-image-skin/
├── README.md
├── LICENSE
├── .gitignore
├── codex-image-skin/
│   ├── SKILL.md
│   ├── agents/openai.yaml
│   ├── assets/
│   │   ├── base-skin.css
│   │   ├── theme.generated.css
│   │   └── renderer-inject.js
│   ├── scripts/
│   │   ├── generate-image-theme.ps1
│   │   ├── install-image-skin.ps1
│   │   ├── start-image-skin.ps1
│   │   ├── verify-image-skin.ps1
│   │   ├── restore-image-skin.ps1
│   │   └── injector.mjs
│   └── references/
│       ├── image-guidelines.md
│       └── qa-checklist.md
└── tests/
    ├── fixtures/
    └── test-generate-image-theme.ps1
```

The repository root serves GitHub users. The nested `codex-image-skin` directory is the installable skill and can be copied directly to `%USERPROFILE%\.codex\skills\codex-image-skin`.

## User Workflow

1. A user provides a PNG, JPEG, or BMP image and requests a Codex theme.
2. The skill verifies the image, copies it locally as `assets/theme-reference.<extension>`, and preserves any prior local theme asset as a timestamped backup.
3. `generate-image-theme.ps1` samples image pixels with `System.Drawing`, derives a readable accent, ink, surface, border, and hero-overlay palette, and writes `assets/theme.generated.css`.
4. The existing CDP launch path opens the official Store-installed Codex executable on loopback, injects `base-skin.css` plus `theme.generated.css`, and adds only pointer-inert decorations.
5. Verification captures a screenshot and checks the injection marker, native composer, sidebar, hero, responsive suggestion-card count, and document overflow.
6. Restore removes the live injected DOM/CSS and can restore the pre-install Codex base-theme configuration.

## Image and Palette Rules

- Accept only local image files supported by `System.Drawing`.
- Downsample to a small grid before sampling so generation stays fast.
- Ignore fully transparent pixels.
- Derive colors from the image's average and high-saturation sampled pixels; generate a cool/warm tint from the image rather than hardcoding a particular color family.
- Choose ink and hero overlay using luminance and contrast checks. A light image receives a dark left overlay; a dark image receives a deeper surface with bright text.
- Keep image use confined to the real home hero and optional small decorative crop. Never place a full-window screenshot over the Codex UI.
- Keep the real project selector, suggestion cards, sidebar, composer, and buttons usable.

## Runtime Safety

- Never edit `app.asar`, `WindowsApps`, the official executable, package ownership, authentication, threads, plugins, or user data.
- Bind the Chromium DevTools Protocol only to `127.0.0.1`.
- Discover the current `OpenAI.Codex` package at launch time; do not embed a versioned WindowsApps path.
- Keep user images, generated CSS, logs, state, and screenshots out of Git by default.
- Revoke the prior artwork object URL before reinjecting a changed image so the active renderer never retains a stale image Blob.

## Skill Content

`SKILL.md` stays concise and contains trigger phrases, a strict workflow, permission guardrails for restarting Codex, and references to detailed image/QA guidance. It directs the agent to run the generation script before launch and to show verification evidence rather than claiming success from script exit status alone.

The package includes generic branding only. It must not refer to prior personal branding, prior artwork, or any user's imagery.

## Testing

- Before implementation, add a PowerShell test that expects the not-yet-created generator to emit `theme.generated.css` from a synthetic fixture and validates the CSS has no placeholder tokens.
- Add three small synthetic fixtures: light cool image, dark warm image, and high-contrast image. Do not use third-party or user artwork.
- Run each fixture through the generator and validate generated color declarations and readable ink/overlay choices.
- Run Node syntax checks for the injector and renderer scripts.
- When Codex is installed, run the verify script with a screenshot and inspect both a new-task home screen and a normal task. When Codex is unavailable, run static script and generated-CSS checks only and clearly report the omitted runtime verification.
- Exercise restore and reapply before release.

## GitHub Presentation

The repository README is Chinese-first with a concise English summary. It covers what the skill does, requirements, installation, image-based generation, launch/verify/restore commands, supported image formats, safety boundaries, troubleshooting, contribution rules, and the license. It must be specific about what is tested and avoid promises of ratings, compatibility with every Codex build, or visual results independent of source-image composition.

Publish as `pokms/codex-image-skin` under the MIT License after the local package passes validation. Use the GitHub account's authenticated browser or Git credentials; do not place access tokens in files, command output, or the repository.

## Acceptance Criteria

- A new user can install the nested skill folder and use a local image to generate a locally stored theme asset and CSS palette.
- The image appears in a real Codex hero without replacing real controls.
- The resulting palette visibly follows the source image while retaining readable text and controls.
- The live skin can be verified, removed, and reapplied without changing official package files.
- The public repository contains only generic code, synthetic fixtures, documentation, and an OSS license.
