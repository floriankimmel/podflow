# Proposal: Claude Code episode flow

## Why

The desktop app grew in a direction that does not match how episodes are actually produced (Reaper/studio profiles, local Ollama, local Parakeet transcription, Dropbox ingest, presets). The real workflow is a single video-first flow: finished video → Auphonic (YouTube + audio server) → transcript (Zencastr or Auphonic) → shownotes / SEO / social → WordPress + manual social posting. Today the content part is done by hand in three separate Copilot chats and copy-pasted.

The app should support exactly this flow and delegate all work (Auphonic, generation, fact-checking, publishing) to Claude Code skills, so both hosts — including a non-technical co-host — can run an episode end to end from the app.

## What Changes

- **Claude Code runtime in the app**: the app installs Claude Code if missing, guides login, and runs the `podflow` Claude Code plugin shipped inside the app bundle headless (`claude -p --plugin-dir … --output-format stream-json --dangerously-skip-permissions`) in the episode folder, showing streamed progress.
- **New `podflow` Claude Code plugin** in `desktop/plugin/`, bundled with the app: orchestration skill, bash + curl + jq scripts for Auphonic, the three existing prompts (shownotes, social, SEO) ported unchanged, plus a headless variant of the `/shownotes` fact-check that writes a report for the review.
- **Single episode flow** with two transcript variants:
  - *Zencastr*: transcript file supplied at episode creation.
  - *Interview compilation*: transcript produced by Auphonic speech recognition.
  - Auphonic runs in two stages: the production is created with `review_before_publishing` (nothing leaves Auphonic), then released with YouTube title/description/tags from the SEO output.
- **Mandatory review step** in the app: editable shownotes, SEO with copy buttons (title tag and Facebook texts are entered manually), one editable card per social platform with copy button, fact-check report, cover and featured image, release date/time.
- **WordPress publishing via the bundled `podflow` CLI** (`podflow publish`: FTP upload of the cover, scheduled post with featured image, Podlove assets, Yoast focus keyword and meta description from `seo.md`) using a per-episode generated config. YouTube link is appended to shownotes first.
- **Shared status** via the existing backend; app passes `PODFLOW_BACKEND_URL` / `PODFLOW_WORKSPACE_KEY` to Claude and the CLI.
- **Resumable runs**: `state.json` per episode, idempotent steps, retry from failed step.
- **Distribution**: signed + notarized `.dmg` on GitHub Releases with Sparkle updates.
- **BREAKING (desktop only)**: remove Ollama (`OllamaClient`), quicksubs/Parakeet (`TranscriptionService`, `DependencyManager`), `RPPGenerator`, Dropbox/Zencastr folder ingest, Studio/Reaper profiles, config presets, `ServerAudioDownloader`, server audio URL template, `AuphonicClient`.

## Out of Scope

- Changes to the Go CLI (`cmd/podflow`, `internal/`) and the backend (`backend/`), except restoring the CLI's config directory broken by the module-path rename.
- Writing the Yoast title tag and Open Graph fields automatically (copy-paste for now).
- Chapter marks (episodes are published without chapters).
- Automatic posting to social platforms.
- Any recording/editing workflow (Reaper, studio profiles).

## Capabilities

- `claude-runtime` — install, login, plugin lifecycle, headless execution.
- `episode-pipeline` — episode creation, Auphonic, transcript, generation, fact-check, publish, resume.
- `episode-review` — review/edit screen and publish trigger.
- `app-distribution` — signed build, bundled CLI, updates.

## Impact

- `desktop/` (app sources, tests, new `desktop/plugin/`); one-line fix in `internal/configuration` and `cmd/podflow`.
- Previous OpenSpec changes (`add-podflow-desktop-foundation`, `add-transcription-content-generation`, `add-auphonic-video-ingest`, `add-config-presets`) are dropped and superseded by this change.
- Requires an Apple Developer account for signing/notarization.
- Each user needs their own Claude Pro account.
