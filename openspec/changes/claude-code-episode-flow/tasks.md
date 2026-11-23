# Tasks

## 1. Verify external assumptions

- [ ] 1.1 Verify Auphonic API: create production with an outgoing service disabled, later enable it and call publish; speech-recognition transcript output format and download. Document result in `design.md`; pick fallback (two presets / `outgoing_services` on publish) if needed. **Docs checked (see design.md); live test production still open.**
- [x] 1.2 Verify Claude Code headless contract: native installer path, auth-status check, `claude plugin marketplace add|update`, `claude plugin install|update`, `claude -p --output-format stream-json --verbose --dangerously-skip-permissions` event shape. Pin findings in `design.md`.
- [x] 1.3 Verify `podflow publish` config keys for a WordPress-only `config.yml` (shownotes, image, poster, release date) against `internal/configuration`.

## 2. Cleanup (desktop only)

- [x] 2.0 Restore CLI config directory `~/.config/podflow` and app name (regression from module-path rename).

- [x] 2.1 Remove `OllamaClient`, `TranscriptionService`, `DependencyManager`, `RPPGenerator`, `ZencastrIngest`/Dropbox ingest, Studio/Reaper profiles, `PresetStore`/presets, `ServerAudioDownloader`, server URL template setting, `AuphonicClient`, `PromptStore`, `GenerationService` and their views/tests; app builds and remaining tests pass.

## 3. Plugin

- [x] 3.1 Add `desktop/plugin/.claude-plugin/plugin.json`; `claude plugin validate` passes. (Marketplace file dropped: plugin ships in the app bundle.)
- [x] 3.2 Move prompts into `desktop/plugin/skills/episode/prompts/` unchanged.
- [x] 3.3 `scripts/state.sh` (get/set step status in `state.json`) and `scripts/backend.sh` (report step); bash + curl + jq only.
- [x] 3.4 `scripts/auphonic.sh` subcommands create|upload|start|status|transcript|metadata|publish per 1.1; test against a stub server.
- [x] 3.5 `skills/episode/SKILL.md` orchestrator with `prepare` and `publish` modes, idempotent steps per `design.md`, transcript wrapped as data, shownotes → social sequential, SEO parallel via subagents.
- [x] 3.6 Add fact-check step: move/adapt existing `/shownotes` skill into the plugin and call it on `shownotes.md` + `social.md`.
- [x] 3.7 Publish steps: Auphonic metadata from `seo.md` YouTube section, publish, append YouTube link to shownotes, run `$PODFLOW_CLI publish`.

## 4. App: Claude runtime

- [x] 4.1 `ClaudeLocator` + installer runner with progress; auth check and login flow.
- [x] 4.2 Load the bundled plugin with `--plugin-dir` (replaces install/update on start).
- [x] 4.3 `ClaudeRunner`: spawn `claude -p` in episode folder with env, parse stream-json into step progress, tee to `run.log`, exit-code handling.

## 5. App: episode flow UI

- [x] 5.1 Onboarding: Claude install/login, credentials → Keychain, preset UUID + backend URL → settings.
- [x] 5.2 New episode sheet: number (prefilled from backend), title, type, video, transcript (zencastr only); create folder + `state.json`.
- [x] 5.3 Episode detail: step list from `state.json` + backend, Start/Retry for `prepare`/`publish`, live log.
- [x] 5.4 Review screen: shownotes editor, SEO sections with copy, social cards (edit + copy), featured image picker, release date/time; Publish gated on image + date; writes files and `config.yml`, then starts `publish`.
- [x] 5.5 Register new episodes in the backend; step status is reported by the plugin's `state.sh` and the CLI.

## 6. Distribution

- [x] 6.1 Build step embedding `podflow` CLI (darwin universal) into the app bundle; pass path as `PODFLOW_CLI`.
- [x] 6.2 Developer ID signing, notarization, `.dmg` release on GitHub; Sparkle appcast + in-app update.

## 7. End-to-end

- [ ] 7.1 Zencastr episode end to end against stubbed Auphonic/WordPress: prepare → review → publish; YouTube description set before publish.
- [ ] 7.2 Interview compilation end to end with Auphonic transcript.
- [ ] 7.3 Retry after induced failure in `auphonic_wait` and `wordpress` skips completed steps (no re-upload).
- [ ] 7.4 Fresh macOS user without Claude Code: install → login → plugin → first episode, no terminal.
