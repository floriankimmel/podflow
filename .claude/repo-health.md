# Repo Health config: podflow

## Scope

May change: Go code and tests (`cmd/`, `internal/`, `backend/`, `test/`),
desktop Swift code and tests (`desktop/Sources`, `desktop/Tests`), plugin
scripts (`desktop/plugin/skills/episode/scripts`), `GLOSSARY.md`, `docs/adr/`,
`CLAUDE.md` files and READMEs.

Never touch:
- `desktop/plugin/skills/episode/prompts/` and the German wording in
  `SKILL.md`: they produce the podcast content.
- `desktop/Info.plist` (version, signing, Sparkle keys), `.goreleaser.yaml`,
  `.github/`, `backend/fly.toml`, `devbox.json`, `devbox.lock`.
- `openspec/` (specs are written with the user).

Renaming a step id, episode file, SEO label or env var must change
`desktop/Sources/Podflow/Models/PluginContract.swift` and the plugin together
(see `desktop/CLAUDE.md`).

## Verify

Run in the worktree root:

```sh
go vet ./... && go test -count=1 ./...
(cd backend && go vet ./... && go test -count=1 ./...)
(cd desktop && env -u DEVELOPER_DIR -u SDKROOT make test)
```

The devbox shell exports a nix `SDKROOT`/`DEVELOPER_DIR` that breaks the Swift
build; unset them as above. `make test` also builds the bundled CLI and runs
the plugin script tests.

Never run `make install`, `make release` or `make publish` in `desktop/`, and
never `fly deploy` in `backend/`: they ship to users.

## Setup

None. The worktree needs no git-ignored files.
