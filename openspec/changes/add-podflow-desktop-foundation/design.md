# Design

## Context

See proposal.md — Why. Podflow is a Go CLI (`internal/commands/publish.go`) that runs a sequence of publish steps and persists per-step booleans to a local `{{folder}}.state.yml` (`internal/state/state.go`). Each step already flips a boolean (`FTPDeleted`, `FTPUploaded`, `Downloaded`, `S3Uploaded`, `WordpressBlogCreated`, `SteadyHqCreated`, `AuphonicProduction`) and writes state after success. Steps come from config (`internal/configuration/config.go`).

Constraints:
- CLI must stay fully functional offline; backend reporting is additive.
- No existing specs; this is greenfield for the shared-state concept.
- Decisions fixed with the user: SwiftUI native macOS app shelling out to the `podflow` binary; fly.io backend as source of truth; single shared team workspace key; transcription/LLM/Zencastr deferred.

## Goals / Non-Goals

**Goals:**
- Minimal, well-defined HTTP contract for episode state shared by CLI and app.
- Additive CLI reporting that maps existing step booleans to richer per-step statuses (pending/in-progress/done/failed) without changing publish behavior.
- SwiftUI app that reads backend state and visualizes pipeline position, matching all observers.
- A configurable storage root so episodes are discovered as subfolders and podflow runs in the right directory.
- Guided onboarding that gets non-technical users to a working setup by detecting/installing external tools.

**Non-Goals:**
- Real-time push transport sophistication (websockets); polling is acceptable for this slice.
- Per-user identity, roles, or fine-grained sharing (single shared workspace key only).
- Writing/triggering publish from the app, or editing content/prompts.
- Backend-side transcription or generation compute.
- Actually using the transcription tools (pi skills, Ollama/parakeet) in this slice — onboarding provisions them but wiring transcription is a later change.

## Decisions

### D1: Backend = source of truth; local state.yml stays as working cache
The CLI keeps writing `state.yml` unchanged and additionally reports to the backend. Rationale: zero regression risk to the proven local flow; backend outages degrade gracefully to today's behavior. Alternative (backend-only state) rejected: couples publish correctness to network availability.

### D2: Step status model richer than booleans
Backend stores per-step status in `{pending, in_progress, done, failed}`. The CLI derives these at runtime: emit `in_progress` before a step, `done`/`failed` after. Existing `state.yml` booleans still gate skip/redo locally; the backend status is a reporting projection. Rationale: enables a meaningful live visualization (spinner vs check vs error) that booleans alone cannot express.

### D3: Episode identity = episode number within the shared workspace
Use the episode number (already in `state.Metadata.EpisodeNumber`) as the stable identity key; fall back to folder slug (`config.EpisodeSlug`) before a number is assigned. Rationale: human-meaningful, already present, unique per show. Trade-off: pre-number reports keyed by slug must reconcile when the number is set — handled by upsert keyed on identity with a slug→number promotion on first numbered report.

### D4: Transport — REST + JSON, adaptive polling for liveness
Endpoints (shape, not final): `GET /episodes`, `GET /episodes/{id}`, `POST /episodes/{id}/steps` (upsert record + step status). Auth via a shared `Authorization`/`X-Workspace-Key` header checked against a server secret. **Polling cadence (resolved):** on-demand only when nothing is in progress (manual refresh / on open / on focus), and **every 5s** while any step for the viewed episode is `in_progress` (active publish/work); stop the 5s loop once no step is in progress. Rationale: zero idle load, near-live during work, no websockets needed.

### D5: Backend stack on fly.io with SQLite
A small stateful HTTP service persisting to a single **SQLite database file on a fly volume** — local storage on the backend is enough at team scale, no separate Postgres. Language left to implementation; a Go service is natural given team familiarity and could share DTOs with the CLI, but any stack meeting the spec is acceptable. Workspace key provided via fly secret. Trade-off: single-writer SQLite is fine for one small fly machine; if the service ever scales horizontally, revisit (out of scope now).

### D6: CLI backend client is a thin, non-fatal reporter
New `internal/backend` client with a `Report(episodeID, metadata, step, status)` call invoked from `publish.go` at each step boundary. All calls best-effort: errors logged, never returned up the publish path. Config adds `backendURL` + `workspaceKey` (config file and/or env). Rationale: isolates network concerns from publish logic; satisfies resilience requirement.

### D7: SwiftUI app structure
Standalone Xcode project (new top-level directory, e.g. `desktop/`), MVVM: a `BackendClient` (URLSession), an episodes list view, and a pipeline view rendering the fixed ordered stages with per-stage status styling. Credential stored in app settings/Keychain. Rationale: native fit for macOS, decoupled from Go build.

### D8: Storage root + episode-as-subfolder discovery
The app persists a single storage root (app settings). Episodes are the immediate subfolders of that root (matches the CleanShot example layout: one folder per episode holding mp3/m4a/chapters/md/png/state.yml). To run podflow for an episode, the app launches the `podflow` binary with its working directory set to that subfolder, since podflow already resolves config/state from its working directory (`config.Dir()`). Rationale: no CLI change needed for discovery; the app owns location, the CLI stays directory-relative. Alternative (per-episode folder pick each time) rejected for worse UX at scale.

### D9: Onboarding provisions dependencies — download/install, do not bundle
Onboarding detects each dependency (pi coding agent, Ollama, parakeet model, podflow CLI), then installs missing ones on confirmation with progress UI. Install by downloading/invoking each tool's own installer rather than bundling binaries inside the app:
- Ollama and the parakeet model are large, update independently, and have their own licensing/update cadence; bundling bloats the app and complicates notarization.
- podflow CLI installs via Homebrew or `go install` / release binary; pi coding agent via its published installer.
- The model is pulled through Ollama as a resumable, progress-reported step.
Staging: this slice requires only podflow CLI + storage root for publish/visualization to be "ready"; pi/Ollama/parakeet are detected and installable now but their downstream use is deferred to the transcription change. Onboarding is re-runnable to finish staged steps. Rationale: keeps the app small and maintainable, respects the staged scope, and still gives non-technical users one guided flow. Alternative (bundle everything) rejected: size, notarization, and update friction.

### D10: Episode ingest — self-contained episode folder, Reaper built in-app
New episode creation copies Zencastr recordings into a new subfolder under the storage root and builds the Reaper project **inside that episode folder**. Confirmed layout (self-contained): `Recordings/` holds the copied source audio, `<slug>.RPP` is the Reaper project (plus `.RPP-bak`/`backup/`), and the generated outputs live alongside — `<slug>.md` (shownotes), `content-<slug>.md` (SEO), `<slug>.png` (cover), `<slug>_wordpress.png`, `<slug>.m4a`, `<number>_<slug>.mp3`, `<slug>.chapters.txt`, `<slug>.state.yml`.

Source is the Zencastr download folder — a Zencastr **episode** folder (e.g. `Resources/zencastr/259/`) that contains one or more `recording-*` subfolders, each with per-speaker files (`*-laufendentdecken.wav`, `*-guest...-der_3.wav`, sometimes `.flac`/`.mp3`/`.mov`/imported `.m4a`). The app **enumerates every `recording-*` and aggregates audio from all of them** (not just `recording-1`). It reproduces the `start-production` logic natively (no shelling): copy all recording audio into `Recordings/`, generate `<slug>.RPP` from the configured Reaper template with one track per speaker, then open the project.

**Speaker map (typically 3 tracks):** Peter ← filename contains `laufendentdecken`; Florian ← `florian`; third/guest ("der 3") ← `guest...` / `der_3` / anything else. The map is app config (extensible for 4+ guest episodes like the 308 example which had Peter/Florian/Geordi/Alexander).

**RPP generation structure (from the item template):** for each speaker track, each matched source file becomes one full-length `<ITEM>` — `POSITION 0`, `LENGTH` = probed duration, `SOFFS 0`, fresh `GUID`/`IGUID` — with a `<SOURCE WAVE|FLAC>` block whose `FILE` is the **relative** `Recordings/<file>` path (self-contained; `RECORD_PATH "Recordings"`). Manual cutting later splits items; generation only lays down the initial single item per source.

Episode number is derived from the source folder name (e.g. `259`) when present. Template/speaker-map are app config (defaults mirror `~/Documents/workspace/dotfiles/reaper/template.RPP` + `item.xml`); the legacy separate `EpisodenProduktion/Aufnahmen` location is dropped. Audio editing + export to mp3/m4a stays manual in Reaper; the app detects the finished audio. Rationale: one self-contained folder per episode matches the storage model and podflow's working-dir assumption.

### D11: Episode profiles — one model, two workflows
Two production workflows must share one episode/state/visualization model. A **profile** per episode selects (a) the ordered pipeline stages shown in the flow visualization and (b) which podflow publish steps run. This change defines the mechanism + the **Studio/Reaper** profile (stages: Ingest→Reaper→[manual edit/export]→Transcribe→Shownotes→Social→SEO→Publish[FTP/Download/S3/WordPress/Steady/Auphonic]). A later change adds the **Video/Auphonic** profile (stages: Video→Auphonic[YouTube+server]→Download audio→Transcribe→Shownotes→Social→SEO→Publish **without** the Auphonic step, since Auphonic ran up front).

Mechanics: the backend episode record stores the profile and per-stage status for the profile's stage set (stages are keyed names, not a fixed enum). The flow view renders whatever stages the profile lists. For publish-step selection, each profile maps to the podflow config/step subset the app runs in the episode folder (Video/Auphonic uses a config without the Auphonic step). Shared downstream (transcription, generation, publish) is profile-agnostic and operates on the episode folder. Ordering flexibility ("Copilot-first vs Auphonic-first") disappears because stages run by dependency: generation starts as soon as a transcript exists, and the YouTube/video description (the SEO prompt's YouTube output) is pushed to the Auphonic metadata when available, else entered later. Rationale: maximizes reuse, keeps the state model open-ended, and lets new workflows be added as profiles rather than parallel code paths.

## UI Design

Native SwiftUI, macOS-standard navigation. Screens below define layout/structure; observable behavior lives in the specs. Not pixel-level — a build-time reference for the app group.

### Visual language — Liquid Glass
- Translucent, frosted "glass" materials (SwiftUI `.ultraThinMaterial`/`.regularMaterial`, `NSVisualEffectView` vibrancy) over a vibrant backdrop; soft specular highlight on the top edge of panels; rounded 16–26 radii; layered depth (window glass → panel glass → interactive glass controls).
- Status accent colors: done = green, in_progress = accent/blue, failed = red, pending = muted/outline. Glossy buttons for primary actions.
- **No text clipping (hard rule):** episode titles and any constrained label MUST truncate with an ellipsis and stay within their container bounds — text must never overflow under a pane/row edge. Full title remains available via selection/detail or hover.

### Window shell
- `NavigationSplitView`: left sidebar = episode list; detail pane = selected episode's flow. Standard macOS toolbar.
- Toolbar: refresh control, a connection/auth status indicator (connected / auth error / no backend), and a Settings button.

### Onboarding (first run / re-run)
- Modal sheet or dedicated window, vertical checklist of dependencies: pi, Ollama, parakeet model, podflow CLI — each row shows name, detected/missing badge, and an Install button with inline progress bar (model row shows download %).
- A storage-root step: "Choose episodes folder" with a folder picker and the resolved path.
- Footer: overall readiness line ("Ready to publish" once podflow CLI + storage set; staged tools shown as optional) and a Done/Finish later action.

### Episode list (sidebar)
- Rows: episode number + title (secondary line: release date). A small status glyph showing the furthest-reached / failed stage. Titles truncate with ellipsis (see no-clipping rule).
- Empty states: "No episodes — set your storage folder" (unset root) and "No episodes found in <root>".

### Episode detail — flow visualization
- Header: episode number, title, release date.
- Pipeline as a vertical (or horizontal) ordered stepper of the fixed stages: FTP delete → FTP upload → Download → S3 → WordPress → Steady → Auphonic.
- Each stage node shows an icon + label with status styling:
  - pending = grey/outline, in_progress = accent + spinner, done = green check, failed = red with error affordance.
- Connectors between nodes reflect progression; failed stage halts visual progression and is visually distinct.
- Auto-refresh (resolved): on-demand when idle; poll every 5s while a step is in progress. Last-updated timestamp shown.

### Settings
- Backend URL + workspace key fields (key stored in Keychain), storage-root picker, and a "Re-run onboarding" button.

> Scope note: Liquid Glass + the mockup SVGs are the authoritative structural/visual reference. No Figma committed; higher-fidelity mockups optional.

## Risks / Trade-offs

- [Polling load / staleness] → adaptive: idle = on-demand only, active = 5s; bounded load, near-live during work.
- [Pre-number identity churn (slug then number)] → upsert promotes slug-keyed record to number on first numbered report; document as known reconcile step.
- [Backend reporting partial failures leave stale remote state] → app shows last-known status; CLI re-reports current step on next run; booleans in local state keep publish correct regardless.
- [Secret handling] → workspace key is a shared secret stored in fly secrets, CLI config, and app Keychain; rotation is manual in this slice.
- [Scope creep toward later slices] → specs explicitly exclude Zencastr/transcription/generation; keep endpoints episode-state only.
- [Dependency installers change / network failures during onboarding] → detect-then-install with explicit per-step success/failure; onboarding re-runnable; never report complete on a failed step.
- [Model download is large] → resumable, progress-reported Ollama pull; staged so publish/visualization readiness does not block on it.
- [podflow is directory-relative, app controls cwd] → app must pass the exact episode subfolder as working directory; mismatched root yields empty discovery state rather than wrong-folder runs.

## Migration Plan

1. Deploy backend to fly.io with persistence + workspace key secret; no clients depend on it yet.
2. Add opt-in CLI reporting (disabled when unconfigured) — safe to ship; no behavior change without config.
3. Ship SwiftUI app reading the backend.
4. Rollback: unset CLI backend config (reverts to pure-local) and/or stop the fly app; publish continues unaffected.

## Open Questions

None. (Visuals: no Figma — the UI Design section + the SVG mockups are the authoritative reference; visual polish happens during the SwiftUI build.)
