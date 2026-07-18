# Baseline Skill Evaluation

## Prompt

Create a reusable public Codex skill that accepts a local user image, derives a safe visual palette, applies a reversible Windows Codex desktop skin through CDP, and prepares the project for GitHub. Do not publish personal artwork.

## Fresh Agent Response

> Some of what we're working on might be easier to explain if I can show it to you in a web browser. I can put together mockups, diagrams, comparisons, and other visuals as we go. This feature is still new and can be token-intensive. Want to try it? (Requires opening a local URL)

## Observed Gaps

- Did not define an image-to-palette generator.
- Did not preserve or verify native Codex controls.
- Did not prohibit edits to `app.asar` or `WindowsApps`.
- Did not constrain CDP to loopback.
- Did not require restart authorization.
- Did not define Git exclusions for uploaded artwork.
- Did not require screenshot verification or a live restore cycle.

## Required Skill Counters

The public skill must make the generation, loopback-only CDP, native-control preservation, restart authorization, Git privacy exclusions, screenshot verification, and restore requirements explicit and mandatory.
