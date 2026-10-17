# Proposal

## Why

Running podflow today means editing a raw `config.yml` (steps, credentials, file paths, release info). That is fine for the technical owner but a barrier for a second, non-technical cutter who just needs to publish an episode the same way every time. There is no way to save the current working configuration under a friendly name and hand it to someone who should never touch YAML. This change adds **configuration presets** to the desktop app so the owner captures a complete, known-good podflow configuration once, and the non-technical cutter picks it from a list per episode — no config file editing.

This builds directly on `add-podflow-desktop-foundation`, which already defines the storage root, per-episode subfolders, and shelling out to the `podflow` CLI with a working directory. Presets are the configuration layer that decides *what config* the CLI runs with for a given episode.

## What Changes

- Add a **preset** concept: a named, saved snapshot of a complete podflow configuration (release info, precondition files, ordered steps, archive). Presets are managed in the desktop app.
- Add **capture current configuration as a preset**: seed a preset from an existing working `config.yml` so the owner's current setup becomes the first reusable preset without retyping it.
- Add **preset management** for the technical owner: create, rename, duplicate, edit, and delete presets. Editing presets is an owner-level action and stays out of the non-technical cutter's normal flow.
- Add **per-episode preset selection** for the non-technical cutter: pick a preset from a simple list when preparing an episode; the app shows a friendly name/description, never raw YAML.
- Add **preset application**: when the app runs podflow for an episode, it ensures the CLI uses the selected preset's configuration (materializing it so `podflow` loads it for that episode's run), without the cutter managing files or environment variables.
- Add a **default preset** so an episode created without an explicit choice still has a valid configuration to run with.
- Add **export/import of a preset bundle**: the owner exports the whole preset library (or a selection) to a single shareable bundle file, and the cutter imports it into their app in one step — so the owner provisions all presets for the non-technical cutter without configuring the cutter's machine by hand.
- Keep secrets out of presets: credential **references** (e.g. `{{env.FTP_PWD}}`) are preserved as-is; presets do not store resolved secret values.

Out of scope for this change: changing the CLI's config schema or any publish-step behavior; cloud/multi-workspace sharing of presets beyond what the desktop-foundation workspace model already provides; editing presets from the non-technical cutter's simplified flow.

## Capabilities

### New Capabilities
- `config-presets`: named snapshots of a complete podflow configuration, managed in the desktop app, seedable from an existing `config.yml`, exportable/importable as a shareable bundle to provision another user, selectable per episode by a non-technical cutter, and applied so the `podflow` CLI runs with the chosen configuration.

### Modified Capabilities
<!-- None: preset selection layers on top of episode-profile/episode-storage-config without changing their requirements. -->

## Impact

- **Desktop app** (`add-podflow-desktop-foundation` `desktop/`): new preset store (persisted preset library), preset management UI for the owner, per-episode preset picker in the cutter flow, and application logic that points a podflow run at the selected preset's config.
- **podflow CLI (Go)**: no schema change required; presets reuse the existing `Configuration` model and the existing config-loading mechanism (`PODFLOW_CONFIG_FILE` / `$HOME/.config/config.yml`). The app is responsible for making the CLI load the right config for a run.
- **Depends on**: `add-podflow-desktop-foundation` (storage root, episode subfolders, running the CLI per episode). Complements `episode-profile` (which stages run) by supplying the configuration values those stages use.
- **Secrets**: unchanged — presets carry `{{env.*}}` references only; resolution still happens at CLI runtime from the environment.
