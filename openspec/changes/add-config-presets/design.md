# Design

## Context

See proposal.md — Why. podflow (Go CLI) loads a single `Configuration` (`internal/configuration/config.go`) from `$HOME/.config/config.yml`, or from the file named by the `PODFLOW_CONFIG_FILE` env var (resolved under `$HOME/.config/`). The desktop app from `add-podflow-desktop-foundation` already discovers episodes as subfolders of a storage root and shells out to `podflow` with its working directory set to the selected episode subfolder. This change adds a preset library on top, so a non-technical cutter selects a known-good configuration instead of editing YAML.

Constraints:
- No change to the CLI config schema or publish behavior; presets reuse the existing `Configuration` shape.
- The non-technical cutter never edits YAML or manages environment variables.
- Presets must not persist resolved secrets; `{{env.*}}` references are retained verbatim.
- Must compose with `episode-profile` (stage selection) without duplicating it.

## Goals / Non-Goals

**Goals:**
- A reusable, named library of complete podflow configurations managed in the app.
- Seed the first presets from an existing working `config.yml` (capture current configuration).
- One-tap per-episode preset selection for the cutter, with a friendly label and no YAML.
- Deterministic application so a podflow run for an episode uses exactly the selected preset.

**Non-Goals:**
- A new CLI config format or any publish-step change.
- Storing or resolving secrets inside presets.
- Multi-workspace/cloud preset sync beyond the existing desktop-foundation workspace model.
- Letting the simplified cutter flow edit preset internals.

## Decisions

### D1: Preset = serialized `Configuration` + metadata
A preset stores a complete podflow `Configuration` (release info, `files`, ordered `steps`, `archive`) plus app-level metadata: id, display name, optional description. Rationale: reuse the proven CLI schema verbatim so application is a straight write of `config.yml`; no translation layer, no drift from CLI capabilities.

### D2: Apply by materializing the preset's config for the run
When the app runs podflow for an episode, it writes the selected preset's `Configuration` to the config location the CLI will load for that run and launches the CLI as today. Preferred mechanism: write the preset to a config file and run the CLI with `PODFLOW_CONFIG_FILE` pointed at it (the existing supported override), so the global `config.yml` is never clobbered and concurrent episodes with different presets stay isolated. Rationale: uses an existing, documented CLI entrypoint; no CLI change.

### D3: Capture current configuration as a preset
Provide an import that reads an existing working `config.yml`, parses it into the `Configuration` model, and saves it as a new named preset. Rationale: the owner's current setup is the obvious first preset; retyping it is error-prone. `{{env.*}}` and placeholder tokens are preserved exactly (no resolution at import).

### D4: Secrets stay as references
Presets persist `{{env.*}}` references verbatim and never store resolved secret values. Resolution continues to happen at CLI runtime from the environment (`ReplaceEnvVariable`). Rationale: a shared, portable preset library must be safe to store and hand off.

### D5: Owner vs cutter surfaces
Two distinct UI surfaces: an owner-facing management surface (create/rename/duplicate/edit/delete, capture-from-config) and a cutter-facing picker (choose a preset for an episode from a list of friendly names). Rationale: keeps the non-technical flow a single safe choice while preserving full control for the owner.

### D6: Default preset and validity
One preset is marked default. An episode with no explicit selection uses the default so a run always has a valid configuration. Selecting/applying a preset validates it parses into a `Configuration`; an invalid preset cannot be applied. Rationale: the cutter should never reach an unrunnable state.

### D7: Preset selection is per-episode, persisted with the episode
The chosen preset id is stored with the episode (alongside its profile) so reopening the episode shows the same selection and re-runs use the same configuration. Rationale: consistency across runs; composes with `episode-profile`'s per-episode model.

## Risks / Trade-offs

- **Preset drift from live CLI config**: a captured preset is a point-in-time snapshot; later manual edits to `config.yml` are not reflected. Mitigated by explicit re-capture/edit in the owner surface.
- **Env assumptions**: a preset referencing `{{env.FOO}}` only works where `FOO` is set. The app surfaces missing referenced env vars at/ before application rather than failing mid-publish (implementation detail; validated in tasks).
- **Overlap with episode-profile**: profile decides *which stages run*; preset supplies *the values*. A preset may include steps a profile excludes — the profile still governs execution, so no conflict.

## Migration / Compatibility

Additive. Users with an existing `config.yml` keep working unchanged; the app simply offers to capture it as a preset. No CLI release is required for this change.

## Open Questions

- Should presets be shared via the desktop-foundation backend/workspace or stay local to the app install? (Default assumption: local app library for this slice; backend sharing deferred.)
