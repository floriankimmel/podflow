# Podflow desktop

The app is the UI; Claude Code does the work. For an episode the app runs
`claude -p "/podflow:episode prepare|publish" --plugin-dir <bundle>/plugin`
headless in the episode folder. User-facing flow and setup are in `README.md`.

## Where things are

| Concern | File |
|---|---|
| Pipeline steps, run orchestration (agent instructions) | `plugin/skills/episode/SKILL.md` |
| Shownotes / social / SEO prompts | `plugin/skills/episode/prompts/` |
| Auphonic API, `state.json` writes, SEO section lookup | `plugin/skills/episode/scripts/{auphonic,state,seo}.sh` |
| Names shared with the plugin and CLI (step ids, files, SEO labels, env vars) | `Sources/Podflow/Models/PluginContract.swift` |
| Episode state, phases, review draft types | `Sources/Podflow/Models/Models.swift` |
| Episode folders on disk, review draft load/save | `Sources/Podflow/Services/EpisodeStore.swift` |
| Starting a prepare/publish run, its outcome | `Sources/Podflow/Services/EpisodePipeline.swift` |
| Claude process, stream-json parsing, bundle paths | `Sources/Podflow/Services/ClaudeRunner.swift` |
| Claude install/login check | `Sources/Podflow/Services/ClaudeSetup.swift` |
| Review logic (autosave, images, release date, publish gate) | `Sources/Podflow/Services/ReviewSession.swift` |
| Config for the bundled CLI's WordPress publish | `Sources/Podflow/Services/PublishConfig.swift` |
| Settings, Keychain secrets, run environment | `Sources/Podflow/Services/SettingsStore.swift` |
| Episode list (local + backend merge), create, delete | `Sources/Podflow/Services/EpisodeCatalog.swift` |
| UI state: selection, active run, log, error banner | `Sources/Podflow/AppModel.swift` |
| Sparkle updates | `Sources/Podflow/Updater.swift`, `Info.plist` (`SUFeedURL`, `SUPublicEDKey`) |

## Commands

```sh
make test      # plugin script tests (Tests/plugin/run.sh, stub Auphonic) + swift test
make app       # build/Podflow.app: release build, plugin, universal CLI, Sparkle, signed
make install   # make app + copy to /Applications
make publish   # ship an update (see README "Release and updates")
```

Always go through `make`. The devbox shell exports a nix `SDKROOT`, which
breaks a plain `swift build`; the Makefile unsets it and uses full Xcode.

## Rules

- Rename a step, episode file, SEO label or env var in
  `PluginContract.swift` and in the plugin together. `PluginContractTests`
  reads `SKILL.md`, the SEO prompt and the scripts and fails on drift.
- `SKILL.md` has one `` ### `<step_id>` `` heading per step, in
  `PipelineStage.all` order.
- `seo.md` is read by `ContentParser` (Swift) and `seo.sh`. Both must give
  what `Tests/fixtures/seo/expected.json` says; add a fixture for new cases.
- The plugin scripts are bash + curl + jq only. Test them in
  `Tests/plugin/run.sh`.
- Real Claude runs cost money (a prepare run is about 3 USD). Pipeline tests
  use a fake `claude` binary; don't start real runs unless asked.
- Signing uses the "Developer ID Application" certificate (team 36V9TVMHF4).
  Keychain items are bound to the signed app in `/Applications`. Releasing
  needs the notarytool profile `podflow`, the Sparkle key in the login
  Keychain, and `gh` logged in as `floriankimmel`.
