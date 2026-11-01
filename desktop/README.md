# Podflow Desktop

Native SwiftUI macOS app for the Laufend-Entdecken podcast production: live
publish-flow visualization from the shared backend, guided onboarding, episode
ingest (Zencastr → Reaper, or video → Auphonic), local transcription and
content generation, and configuration presets for non-technical cutters.

## Build

Requires full Xcode (SwiftUI needs the macOS SDK from Xcode, not the CLT):

```sh
cd desktop
make app      # builds build/Podflow.app (release, ad-hoc signed, with icon)
make run      # build + open
make test     # unit tests (43)
```

`make` uses `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`;
override on the command line when Xcode lives elsewhere.

## First run — onboarding

The guided onboarding detects and installs the external tools (design D9 —
download/install, never bundle):

| Tool | Needed for | Install path |
| --- | --- | --- |
| podflow CLI | Publish (required) | Homebrew / `go install` |
| Ollama | Transcription + generation | Homebrew cask |
| parakeet | Transcription (ASR) | `ollama pull`, resumable with progress |
| qwen2.5:14b-instruct | Generation (7b on 16GB) | `ollama pull`, resumable |
| pi coding agent | Prompt orchestration (optional) | Homebrew |

“Ready to publish” needs only the podflow CLI + the storage root; the model
tools are staged and installable later (re-run onboarding from Settings).

## Episodes

Episodes are the immediate subfolders of the configured storage root. The app
runs `podflow` with its working directory set to the selected episode folder.
Per-episode app settings (profile, preset) live in `.podflow-app.json` inside
the folder.

### Profiles

- **Studio / Reaper**: Ingest → Reaper → Transcribe → Shownotes → Social → SEO
  → Publish (FTP delete/upload, Download, S3, WordPress, Steady, Auphonic).
- **Video / Auphonic**: Video → Auphonic (YouTube + server) → Download audio →
  Transcribe → … → Publish **without** the Auphonic step (it ran up front).
  The generated YouTube description is passed into the Auphonic metadata when
  it already exists, or applied later via metadata update.

### New episode (studio)

Pick the Zencastr episode folder (e.g. `zencastr/259/`): every `recording-*`
subfolder is aggregated, audio is copied to `Recordings/`, and the Reaper
project is generated from the bundled template (one track per speaker:
Peter ← `laufendentdecken`, Florian ← `florian`, guest ← rest). Editing and
export to mp3/m4a stay manual in Reaper; the app detects the finished audio.

## Presets

Named snapshots of a complete podflow configuration (`config.yml` schema,
verbatim — `{{env.*}}` secret references preserved, never resolved values):

- **Capture**: import an existing working `config.yml` as the first preset.
- **Manage** (owner): create, rename, duplicate, edit (YAML), delete, set
  default. A default always exists.
- **Export/Import**: the whole library as one JSON bundle — a new cutter is
  provisioned with a single import.
- **Select** (cutter): pick a preset per episode by name; no YAML anywhere.
- **Apply**: the app writes the preset to `~/.config/podflow/preset-run-*.yml`
  and launches the CLI with `PODFLOW_CONFIG_FILE` pointing at it — the global
  `config.yml` is never touched, concurrent runs stay isolated. Missing
  `{{env.*}}` variables are surfaced before the run.

## Transcription & generation

Local-first via Ollama: quicksubs + parakeet produce
`<slug>.transcript.txt`; the instruct model generates shownotes
(`<slug>.md`, podflow's configured shownotes path), social posts for Discord/
LinkedIn/Instagram/Strava/Facebook/YouTube (`<slug>.social.md`), and SEO
metadata (`content-<slug>.md` with `**Meta-Description:**` /
`**Focus Keywords:**`, exactly what podflow parses). Each step is stateful:
skip when done, force re-run from the context menu; manual edits are kept.
Prompts are editable Markdown (menu → "Prompts bearbeiten…"), persisted in
Application Support and used on the next run.

## Backend

Settings hold the backend URL and the shared workspace key (Keychain). All
step statuses and generated content are reported to the backend; everyone with
the key sees the same state. Polling: on demand when idle, every 5 s while a
step is in progress.
