# podflow backend

Source of truth for shared episode publish state. Small Go HTTP service with a
SQLite database file, deployed on fly.io with a persistent volume.

## Run locally

```sh
WORKSPACE_KEY=dev-key DATABASE_PATH=/tmp/podflow.db go run .
```

## Deploy (fly.io)

```sh
fly volumes create podflow_data --size 1
fly secrets set WORKSPACE_KEY=<shared team key>
fly deploy
```

## Auth

Every endpoint except `GET /health` requires the shared workspace key, sent as
either header:

```
X-Workspace-Key: <key>
Authorization: Bearer <key>
```

Wrong or missing key → `401 {"error":"invalid workspace key"}`.

## Data model

- **Episode identity**: the episode number (`"259"`) once assigned, the folder
  slug before that. A report that carries both number and slug promotes an
  existing slug-keyed record to the number (steps and content move with it).
- **Step status enum**: `pending` | `in_progress` | `done` | `failed`.
- **Steps are keyed names**, not a fixed enum — the episode profile decides
  which stages exist. The CLI reports: `ftp_delete`, `ftp_upload`, `download`,
  `s3`, `wordpress`, `steady`, `auphonic`. The app additionally reports:
  `ingest`, `reaper`, `video`, `auphonic_production`, `download_audio`,
  `transcribe`, `shownotes`, `social`, `seo`.
- **Profile**: stored per episode (`studio` | `video`), set at creation.
- **Content**: named text artifacts per episode (`transcript`, `shownotes`,
  `social_discord`, …, `seo`) for shared viewing.

## Endpoints

### `GET /health`

```sh
curl http://localhost:8080/health
# {"status":"ok"}
```

### `GET /episodes`

List all episodes (newest number first), each with metadata + per-step status.
Content bodies are omitted in the list.

```sh
curl -H "X-Workspace-Key: dev-key" http://localhost:8080/episodes
```

### `GET /episodes/{id}`

One episode with steps and content. `404` when unknown.

```sh
curl -H "X-Workspace-Key: dev-key" http://localhost:8080/episodes/259
```

### `DELETE /episodes/{id}`

Remove an episode with its steps and content. `404` when it does not exist.
A later step report for the same number creates a fresh episode.

```sh
curl -X DELETE -H "X-Workspace-Key: dev-key" http://localhost:8080/episodes/259
```

### `POST /episodes/{id}/steps`

Upsert a step status. Creates the episode on first report.

```sh
curl -X POST -H "X-Workspace-Key: dev-key" -H "Content-Type: application/json" \
  -d '{"step":"ftp_upload","status":"in_progress","metadata":{"episodeNumber":"259","slug":"259_marathon","title":"Marathon Spezial","releaseDate":"2026-11-05","profile":"studio"}}' \
  http://localhost:8080/episodes/259/steps
```

Unknown status → `400`. Empty step → `400`.

### `POST /episodes/{id}/metadata`

Upsert metadata (title, release date, profile) without touching steps.

```sh
curl -X POST -H "X-Workspace-Key: dev-key" -H "Content-Type: application/json" \
  -d '{"episodeNumber":"300","title":"Video Folge","profile":"video"}' \
  http://localhost:8080/episodes/300/metadata
```

### `POST /episodes/{id}/content`

Store a named content artifact for shared viewing. `404` when the episode does
not exist yet.

```sh
curl -X POST -H "X-Workspace-Key: dev-key" -H "Content-Type: application/json" \
  -d '{"key":"shownotes","body":"# Folge 259"}' \
  http://localhost:8080/episodes/259/content
```

## Tests

```sh
CGO_ENABLED=0 go test ./...
```
