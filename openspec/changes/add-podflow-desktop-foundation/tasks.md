# Tasks

## 1. Backend service scaffold (fly.io)

- [ ] 1.1 Create the backend service project in a new top-level `backend/` directory with an HTTP server skeleton; verify `GET /health` returns 200 locally.
- [ ] 1.2 Add SQLite persistence (single DB file on a fly volume) and an `episodes` store with migrations; verify a startup migration creates the schema and a smoke test can insert/read an episode row.
- [ ] 1.3 Add `fly.toml` + Dockerfile and a persistent volume/secret for the workspace key; verify `fly deploy` succeeds to a staging app and `/health` is reachable over HTTPS.

## 2. Backend API + shared-workspace auth

- [ ] 2.1 Implement shared-workspace auth middleware checking the workspace key header against a server secret; verify a request without/with wrong key gets an auth error and a valid key passes (middleware unit test).
- [ ] 2.2 Implement `GET /episodes` and `GET /episodes/{id}` returning metadata + per-step status; verify integration tests cover list, found, and not-found.
- [ ] 2.3 Implement `POST /episodes/{id}/steps` upsert (create-on-first-report, update otherwise) with step-status validation `{pending,in_progress,done,failed}` and the defined step set; verify tests cover create, update, unknown-step rejection, and slug→number promotion.
- [ ] 2.4 Verify shared-view consistency: an integration test reports a step then fetches via two independent reads and asserts identical state.
- [ ] 2.5 Document the HTTP contract (endpoints, auth header, step/status enums) in `backend/README.md`; verify the documented example requests run against the local server.

## 3. CLI backend-sync capability

- [ ] 3.1 Add backend config (`backendURL`, `workspaceKey`) to `internal/configuration` via config file and/or env; verify a config unit test loads both and treats them as optional.
- [ ] 3.2 Implement `internal/backend` client with a best-effort `Report(episodeID, metadata, step, status)`; verify unit tests assert non-fatal behavior (unreachable/error returns no error to caller) using a test HTTP server.
- [ ] 3.3 Derive a stable episode identity (episode number, slug fallback) and map metadata; verify a unit test produces the expected identity before and after a number is assigned.
- [ ] 3.4 Wire reporting into `internal/commands/publish.go` at each step boundary (in_progress before, done on success, failed on error) for all stages (FTP delete, FTP upload, Download, S3, WordPress, Steady, Auphonic); verify a publish test with a stub backend records the expected sequence of step reports.
- [ ] 3.5 Verify resilience: a publish test with the backend unreachable/disabled completes the pipeline and writes local `state.yml` unchanged, confirming additive, non-breaking behavior.
- [ ] 3.6 Update `README.md` with the new backend config and the behavior-when-unconfigured note; verify the documented config keys match the implemented ones.

## 4. SwiftUI macOS app

- [ ] 4.1 Create a new `desktop/` Xcode macOS app project with MVVM scaffold and the `NavigationSplitView` window shell (sidebar + detail + toolbar) per design.md UI Design; verify the project builds and launches showing the shell with empty states.
- [ ] 4.2 Implement settings for backend URL + workspace credential stored in Keychain; verify entering/persisting a credential survives relaunch (manual + a credential-store unit test).
- [ ] 4.3 Implement `BackendClient` (URLSession) for list/get with auth header and an auth-error state; verify unit tests against a mocked URLSession cover success and rejected-credential paths.
- [ ] 4.4 Implement the episode list view bound to backend data showing number/title/release date; verify it renders a mocked episode list and shows the auth-error state when the credential is rejected.
- [ ] 4.5 Implement the pipeline visualization: fixed ordered stages (FTP delete, FTP upload, Download, S3, WordPress, Steady, Auphonic) with pending/in-progress/done/failed styling, plus polling refresh for the selected episode; verify a view/model test maps backend statuses to the correct stage visuals including a distinct failed state and reflects a changed state without restart.

## 5. Storage root + episode discovery

- [ ] 5.1 Implement a persisted storage-root setting (folder picker, stored in app settings); verify the chosen root survives relaunch and an unset/missing root shows a needs-configuration state.
- [ ] 5.2 Discover episodes as immediate subfolders of the root and present them; verify a test against a temp directory lists subfolders as episodes and shows an empty state for an empty root.
- [ ] 5.3 Launch `podflow` with its working directory set to the selected episode subfolder; verify an integration test confirms the process runs with the expected cwd for a chosen episode.

## 6. Guided onboarding

- [ ] 6.1 Implement dependency detection for pi coding agent, Ollama, parakeet model, and podflow CLI with per-dependency status; verify a test reports detected vs missing for a stubbed environment.
- [ ] 6.2 Implement guided install of missing dependencies via their own installers (Homebrew/go install/release for podflow, installer for pi, Ollama installer) with progress and per-step success/failure; verify install failures surface and onboarding does not report complete.
- [ ] 6.3 Implement resumable parakeet model download through Ollama with progress; verify the model-pull step reports progress and completion against a stubbed/ mocked Ollama.
- [ ] 6.4 Add the storage-root selection step to onboarding and persist it; verify choosing a root marks the storage step complete and feeds group 5.
- [ ] 6.5 Implement completion/readiness logic (ready when podflow CLI + storage root present; transcription tools staged) and re-run support; verify ready state with staged deps, and that re-running re-checks all dependencies.

## 7. Episode ingest (new episode)

- [ ] 7.1 Implement "new episode from Zencastr recordings": select the Zencastr episode source (e.g. `Resources/zencastr/<n>/`), enumerate **all** `recording-*` subfolders, name/derive episode number, create a subfolder under the storage root, copy audio from every recording into a `Recordings/` area inside it; verify a test aggregates audio across multiple `recording-*` and the episode becomes discoverable.
- [ ] 7.2 Reproduce start-production natively: generate the Reaper `.RPP` inside the episode folder from the configured template, one track per speaker (Peter←`laufendentdecken`, Florian←`florian`, third/guest←`guest`/`der_3`/else; typically 3 tracks), each matched source placed as a full-length item (`POSITION 0`, probed `LENGTH`, `SOFFS 0`, fresh GUIDs, `<SOURCE WAVE|FLAC>` with relative `Recordings/<file>`), then open the project; verify a test builds the expected tracks+items for a sample recording set.
- [ ] 7.3 Make ingest config (Reaper template + item xml, speaker map) overridable with defaults mirroring the current dotfiles templates; verify config loads defaults and can be overridden, and that nothing writes to the legacy EpisodenProduktion path.
- [ ] 7.4 Detect finished edited audio (mp3 + m4a) in the episode folder and reflect an "awaiting edited audio" state when absent; verify a test toggles the state based on audio presence.

## 8. Episode profiles

- [ ] 8.1 Add an episode profile stored with the episode (chosen at creation, default Studio/Reaper) in the backend record; verify a test persists and reads the profile.
- [ ] 8.2 Derive the flow-view stage set + order from the profile (stages as keyed names, not a fixed enum) so the visualization renders profile-defined stages; verify the Studio profile renders its stage set and a second mock profile renders a different set.
- [ ] 8.3 Select the podflow config/step subset by profile so publish runs only the profile's steps (enables excluding a step like Auphonic for other profiles); verify a test runs publish for a profile that excludes a step and confirms it is skipped and not reported as pending.

## 9. Pre-publish readiness & follow-up

- [ ] 9.1 Implement the pre-publish readiness check (required files: mp3, m4a, chapters, cover art png, shownotes, SEO content file) surfacing missing items; verify a test reports ready vs names the missing file (e.g. cover art).
- [ ] 9.2 Show a post-publish reminder for the manual Patreon upload; verify the reminder appears after a successful publish.

## 10. End-to-end integration

- [ ] 10.1 Verify full loop against the deployed backend: run `podflow publish` (configured) on a test episode in the configured storage root and confirm the app reflects live stage transitions (in-progress → done) and a failed stage renders distinctly.
- [ ] 10.2 Verify shared-state parity: two app instances with the same workspace key viewing the same episode show identical per-step statuses.
- [ ] 10.3 Verify ingest-to-publish path: create a new episode from Zencastr recordings (Studio profile), confirm the Reaper project opens, then (with edited audio + required files present) pass the readiness check and run publish successfully.
- [ ] 10.4 Verify onboarding-to-publish path: a fresh setup completes onboarding (podflow CLI + storage root), discovers an episode subfolder, and runs publish successfully.

## Workflow follow-up

- Archive the change after the project's review requirements are satisfied.
- Verify the archived result.
