# Tasks

## 1. Preset model + store

- [ ] 1.1 Define a preset model (id, display name, optional description, serialized podflow `Configuration`, default flag) reusing the CLI `Configuration` schema; verify a round-trip serialize/deserialize test preserves all fields including `{{env.*}}` references verbatim.
- [ ] 1.2 Implement a persisted preset library (list/get/create/update/delete/set-default) in the desktop app; verify presets survive app relaunch and that exactly one preset is default at any time.

## 2. Capture current configuration

- [ ] 2.1 Implement import that reads an existing `config.yml`, parses it into the `Configuration` model, and saves it as a named preset; verify the created preset's configuration equals the source file and placeholder/secret references are unchanged.
- [ ] 2.2 Verify the first captured preset is offered as the default when the library was empty.

## 3. Owner management UI

- [ ] 3.1 Build the owner-facing management surface (create, rename, duplicate, edit, delete, set default, capture-from-config); verify each action updates the persisted library and the UI reflects it.
- [ ] 3.2 Verify delete removes a preset from selectable lists and that deleting the default promotes another preset (or blocks deletion of the last/default) so a default always exists.

## 4. Export / import preset bundle

- [ ] 4.1 Implement export of the preset library (all or selected) to a single bundle file; verify the bundle round-trips through import to equal presets, with `{{env.*}}` references preserved and no resolved secrets written.
- [ ] 4.2 Implement import that adds bundled presets to the library in one action and reconciles id/display-name collisions without data loss; verify importing onto a non-empty library keeps both colliding presets as distinct entries.
- [ ] 4.3 Verify a clean cutter install reaches a fully provisioned, selectable preset set after a single import, with no manual config editing.

## 5. Cutter selection UI

- [ ] 5.1 Build the cutter-facing picker that lists presets by display name/description with no raw config editing; verify selecting a preset records the chosen preset id with the episode.
- [ ] 5.2 Verify reopening an episode shows the previously selected preset, and an episode with no selection shows/uses the default.

## 6. Apply preset to a podflow run

- [ ] 6.1 Implement application that materializes the selected preset's configuration to a per-run config file and launches `podflow` with `PODFLOW_CONFIG_FILE` pointed at it in the episode's working directory; verify an integration test confirms the CLI loads the preset's config and the global `config.yml` is not modified.
- [ ] 6.2 Verify two episodes with different presets run isolated (each run uses its own config) via a concurrent/sequential test with distinct temp configs.
- [ ] 6.3 Verify secret references resolve at CLI runtime from the environment (preset stores `{{env.*}}` only), with a test setting an env var and asserting the resolved value is used.

## 7. Validation + safety

- [ ] 7.1 Validate a preset parses into a complete `Configuration` before application; verify an invalid/corrupt preset is blocked with a user-visible error and podflow is not run.
- [ ] 7.2 Surface missing referenced env vars for the selected preset before/at application rather than failing mid-publish; verify a test flags an unset referenced env var.

## 8. Docs

- [ ] 8.1 Document presets (capture current config, manage, export/import bundle, select per episode) in the desktop app docs/README; verify the described flow matches the implemented UI and the `PODFLOW_CONFIG_FILE` application mechanism.
