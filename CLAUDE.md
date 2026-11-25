# Podflow

Tooling for publishing episodes of the Laufend Entdecken podcast. Three
programs live in this repo:

| Path | What | Language |
|---|---|---|
| `cmd/podflow`, `internal/` | `podflow` CLI: config-driven publish steps (FTP, S3, Auphonic, SteadyHQ, WordPress), chapter marks, resumable state | Go module `github.com/floriankimmel/podflow` |
| `backend/` | Shared episode-state service on fly.io (`podflow-backend`), SQLite, `X-Workspace-Key` auth | separate Go module |
| `desktop/` | SwiftUI macOS app plus a Claude Code plugin; the app runs the plugin headless for the episode flow and bundles the CLI | Swift, bash, Markdown. See `desktop/CLAUDE.md` |

Domain terms (Episode, Review, Cover, Featured image, Publish, …) are defined in
`GLOSSARY.md`. Use them in code, docs and commits.

## Commands

```sh
make build                       # CLI: go mod tidy + build to bin/ and ~/go/bin
go test -count=1 ./...           # CLI tests (Ginkgo/Gomega suites, *_suite_test.go)
golangci-lint run                # CLI lint
(cd backend && go test ./...)    # backend tests
(cd backend && fly deploy)       # backend deploy
cd desktop && make test          # plugin script tests + Swift tests
```

The dev shell is devbox (`devbox.json`, loaded by direnv). It pins Go 1.21.

## Conventions

- Conventional Commits with a capitalised subject (`feat(desktop): Add …`),
  enforced by commitlint. Scopes in use: `desktop`, `backend`, `cli`,
  `openspec`, `go`, `ci`.
- Pre-commit runs gitleaks, gofmt/goimports, golangci-lint and the Go tests.
- CLI tests use Ginkgo/Gomega, not plain `testing` assertions (pre-commit hook
  `no-go-testing`).
- Code, comments and docs are in English. The desktop UI and the generated
  podcast content (prompts, shownotes) are in German.
- Specs and planned changes live in `openspec/` (`openspec/changes/<change>/`:
  proposal, design, specs, tasks). The active change is
  `claude-code-episode-flow`.

## Things that bite

- `podflow publish` reads its config only from `~/.config/podflow/<file>`; the
  file is picked by `PODFLOW_CONFIG_FILE`. The desktop app instead runs
  `podflow publish-episode publish.json`, which needs no config file. Per-folder
  progress is in `<folder>.state.yml`.
- Credentials (Auphonic, WordPress, FTP, workspace key) come from environment
  variables or the macOS Keychain. Never print, log or commit them.
- GitHub releases: CLI releases come from goreleaser and own "latest". Desktop
  releases are tagged `desktop-v<version>` and must stay out of "latest" (the
  `make publish` target in `desktop/` handles that).
