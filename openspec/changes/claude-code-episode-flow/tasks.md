# Tasks

## 1. Verify external assumptions

- [ ] 1.1 Verify Auphonic API: create production with an outgoing service disabled, later enable it and call publish; speech-recognition transcript output format and download. Document result in `design.md`; pick fallback (two presets / `outgoing_services` on publish) if needed.
- [ ] 1.2 Verify Claude Code headless contract: native installer path, auth-status check, `claude plugin marketplace add|update`, `claude plugin install|update`, `claude -p --output-format stream-json --verbose --dangerously-skip-permissions` event shape. Pin findings in `design.md`.
- [ ] 1.3 Verify `podflow publish` config keys for a WordPress-only `config.yml` (shownotes, image, poster, release date) against `internal/configuration`.

## 2. Cleanup (desktop only)

- [ ] 2.1 Remove `OllamaClient`, `TranscriptionService`, `DependencyManager`, `RPPGenerator`, `ZencastrIngest`/Dropbox ingest, Studio/Reaper profiles, `PresetStore`/presets, `ServerAudioDownloader`, server URL template setting, `AuphonicClient`, `PromptStore`, `GenerationService` and their views/tests; app builds and remaining tests pass.

## 3. Plugin

- [ ] 3.1 Add `.claude-plugin/marketplace.json` at repo root and `desktop/plugin/.claude-plugin/plugin.json`; verify `claude plugin marketplace add` + `install` from a local path.
- [ ] 3.2 Move prompts into `desktop/plugin/skills/episode/prompts/` unchanged.
- [ ] 3.3 `scripts/state.sh` (get/set step status in `state.json`) and `scripts/backend.sh` (report step); bash + curl + jq only.
- [ ] 3.4 `scripts/auphonic.sh` subcommands create|upload|start|status|transcript|metadata|publish per 1.1; test against a stub server.
- [ ] 3.5 `skills/episode/SKILL.md` orchestrator with `prepare` and `publish` modes, idempotent steps per `design.md`, transcript wrapped as data, shownotes → social sequential, SEO parallel via subagents.
- [ ] 3.6 Add fact-check step: move/adapt existing `/shownotes` skill into the plugin and call it on `shownotes.md` + `social.md`.
- [ ] 3.7 Publish steps: Auphonic metadata from `seo.md` YouTube section, publish, append YouTube link to shownotes, run `$PODFLOW_CLI publish`.

## 4. App: Claude runtime

- [ ] 4.1 `ClaudeLocator` + installer runner with progress; auth check and login flow.
- [ ] 4.2 Plugin install/update on start (non-fatal update failures).
- [ ] 4.3 `ClaudeRunner`: spawn `claude -p` in episode folder with env, parse stream-json into step progress, tee to `run.log`, exit-code handling.

## 5. App: episode flow UI

- [ ] 5.1 Onboarding: Claude install/login, credentials → Keychain, preset UUID + backend URL → settings.
- [ ] 5.2 New episode sheet: number (prefilled from backend), title, type, video, transcript (zencastr only); create folder + `state.json`.
- [ ] 5.3 Episode detail: step list from `state.json` + backend, Start/Retry for `prepare`/`publish`, live log.
- [ ] 5.4 Review screen: shownotes editor, SEO sections with copy, social cards (edit + copy), featured image picker, release date/time; Publish gated on image + date; writes files and `config.yml`, then starts `publish`.
- [ ] 5.5 Report app-side steps (created, review, published) to backend.

## 6. Distribution

- [ ] 6.1 Build step embedding `podflow` CLI (darwin universal) into the app bundle; pass path as `PODFLOW_CLI`.
- [ ] 6.2 Developer ID signing, notarization, `.dmg` release on GitHub; Sparkle appcast + in-app update.

## 7. End-to-end

- [ ] 7.1 Zencastr episode end to end against stubbed Auphonic/WordPress: prepare → review → publish; YouTube description set before publish.
- [ ] 7.2 Interview episode end to end with Auphonic transcript.
- [ ] 7.3 Retry after induced failure in `auphonic_wait` and `wordpress` skips completed steps (no re-upload).
- [ ] 7.4 Fresh macOS user without Claude Code: install → login → plugin → first episode, no terminal.
