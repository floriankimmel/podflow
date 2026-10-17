# Proposal

## Why

Podflow today is a single-user CLI whose episode progress lives only in a local `{{folder}}.state.yml`. The team cannot see where an episode currently is in the publish pipeline, and there is no shared, authoritative view of state. This change lays the foundation for a desktop app that visualizes the live publish flow and shares the exact same state across everyone on the team, by introducing a backend as the source of truth and teaching the CLI to report progress to it.

This is the first slice of a larger vision (Zencastr ingest, local transcription, and AI-generated shownotes/social posts). Those pre-publish steps are intentionally out of scope here and will be added as later changes on top of this foundation.

## What Changes

- Introduce a **fly.io backend API** that stores episode publish state for a single shared team workspace and serves it as the source of truth.
- Define a **shared episode-state model** (episode identity, metadata, per-step status) that both the CLI and the app agree on.
- Teach the **podflow CLI** to push its step state to the backend as `publish` progresses, so remote observers see live updates. Local `state.yml` remains a working cache/mirror; the backend is authoritative for shared viewing.
- Add a **native SwiftUI macOS app shell** that authenticates with the shared workspace key and renders a **flow visualization** of the current publish pipeline (FTP delete/upload, Download, S3, WordPress, Steady, Auphonic), reflecting live state from the backend.
- Add a **configurable episode storage location**: a root folder on the user's machine under which each episode lives in its own subfolder. The app lists episodes from this root and runs podflow in the selected episode's subfolder.
- Add a **guided onboarding** flow for non-technical users that detects and installs required external tools (pi coding agent, Ollama + the parakeet model, and the podflow CLI) and sets the storage root. This slice provisions what publish/visualization needs (podflow CLI + storage) and stages the transcription/skills tools (pi, Ollama, parakeet) for the later transcription change.
- Add **new-episode ingest** with two sources: (a) **select Zencastr files** from a folder (e.g. Downloads) — the app creates a new episode subfolder under the storage root and copies the files in; (b) **Dropbox backup** — the app natively reproduces the current `start-production` setup (place recordings, build the per-speaker editing project from a template, run the shownotes helpers). Audio editing/export to final mp3/m4a stays manual (external Reaper); the app then picks up the finished audio.
- Add **episode profiles**: each episode has a profile that selects its ordered pipeline stages and which publish steps run. This change defines the profile mechanism and the **Studio/Reaper** profile; a later change adds the **Video/Auphonic** profile. The flow visualization renders whatever stages the episode's profile defines.
- Everyone with the workspace key sees the same episodes and the same per-step status.

Out of scope for this change (planned as later changes): local transcription (quicksubs + parakeet/ollama), AI shownote/social generation, and the in-app markdown prompt editor. Audio editing/export (Reaper) is manual and out of scope.

## Capabilities

### New Capabilities
- `episode-state-backend`: fly.io-hosted API that is the source of truth for shared episode publish state; owns the shared-workspace auth model, episode records, and per-step status storage/retrieval.
- `cli-state-sync`: podflow CLI capability that reports local publish progress (per-step status and episode metadata) to the backend during `publish`, keeping the shared state current without breaking offline/local operation.
- `desktop-flow-visualization`: native macOS app that authenticates to the shared workspace and renders a live visualization of an episode's position in the publish pipeline from backend state.
- `episode-storage-config`: configurable on-machine storage root under which episodes live as subfolders; used to discover episodes and to run podflow in the right directory.
- `app-onboarding`: guided first-run flow that detects, installs, and verifies required external dependencies and configures the storage root, so non-technical users reach a working setup.
- `episode-ingest`: create a new episode under the storage root from Zencastr recordings — either by copying user-selected files into a new episode subfolder, or by reproducing the Dropbox-backup production setup in-app.
- `episode-profile`: an episode's profile that selects its ordered pipeline stages and which publish steps run, so different production workflows share one episode/state/visualization model.

### Modified Capabilities
<!-- None: podflow has no existing specs; all behavior here is new. -->

## Impact

- **New backend service**: fly.io app (HTTP API + persistence) — new deployment, secrets, and shared workspace key.
- **New desktop app**: native SwiftUI macOS project (new codebase/target), shells out to the installed `podflow` binary and reads backend state. Includes onboarding/dependency-provisioning and a persisted storage-root setting.
- **External dependency provisioning**: onboarding installs/verifies pi coding agent, Ollama + parakeet model, and the podflow CLI. Decision on bundling vs downloading is in design.md (D9).
- **podflow CLI (Go)**: `internal/commands/publish.go` and `internal/state` gain backend-sync behavior; new config for backend URL + workspace key. Must remain functional when the backend is unreachable.
- **Dependencies/config**: new backend client in Go; backend URL and workspace credential added to configuration/secrets.
- **No changes** to existing publish targets (FTP/S3/WordPress/Steady/Auphonic) behavior beyond emitting state updates.
