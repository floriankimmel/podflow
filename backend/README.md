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

- **Episode identity**: the episode number (`"259"`), taken from the URL path.
  An episode gets its number when its production starts; nothing is stored
  before that. Responses carry it as `episodeNumber` and, for older clients,
  as `id`.
- **Step status enum**: `pending` | `in_progress` | `done` | `failed`.
- **Steps are keyed names**, not a fixed enum — the episode profile decides
  which stages exist. The CLI reports: `ftp_delete`, `ftp_upload`, `download`,
  `s3`, `wordpress`, `steady`, `auphonic`. The app additionally reports:
  `ingest`, `reaper`, `video`, `auphonic_production`, `download_audio`,
  `transcribe`, `shownotes`, `social`, `seo`.
- **Profile**: stored per episode (`studio` | `video`), set at creation.

## Endpoints

### `GET /health`

```sh
curl http://localhost:8080/health
# {"status":"ok"}
```

### `GET /episodes`

List all episodes (newest number first), each with metadata + per-step status.

```sh
curl -H "X-Workspace-Key: dev-key" http://localhost:8080/episodes
```

### `GET /episodes/{number}`

One episode with its steps. `404` when unknown.

```sh
curl -H "X-Workspace-Key: dev-key" http://localhost:8080/episodes/259
```

### `DELETE /episodes/{number}`

Remove an episode with its steps. `404` when it does not exist.
A later step report for the same number creates a fresh episode.

```sh
curl -X DELETE -H "X-Workspace-Key: dev-key" http://localhost:8080/episodes/259
```

### `POST /episodes/{number}/steps`

Upsert a step status. Creates the episode on first report.

```sh
curl -X POST -H "X-Workspace-Key: dev-key" -H "Content-Type: application/json" \
  -d '{"step":"ftp_upload","status":"in_progress","metadata":{"title":"Marathon Spezial","releaseDate":"2026-11-05","profile":"studio"}}' \
  http://localhost:8080/episodes/259/steps
```

Unknown status → `400`. Empty step → `400`.

### `POST /episodes/{number}/metadata`

Upsert metadata (title, release date, profile) without touching steps.

```sh
curl -X POST -H "X-Workspace-Key: dev-key" -H "Content-Type: application/json" \
  -d '{"title":"Video Folge","profile":"video"}' \
  http://localhost:8080/episodes/300/metadata
```

