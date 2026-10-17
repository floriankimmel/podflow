# Spec Delta

## Purpose

Lets a technical owner save a complete podflow configuration under a friendly name and lets a non-technical cutter pick that configuration per episode, so episodes publish with a known-good setup without anyone editing YAML.

## ADDED Requirements

### Requirement: Preset is a named complete configuration
The system SHALL represent a preset as a named snapshot of a complete podflow configuration (release info, precondition files, ordered steps, and archive), identified by a stable id and a human-friendly display name.

#### Scenario: Preset carries a full configuration
- **WHEN** a preset is saved
- **THEN** it stores a complete podflow configuration and a display name that uniquely identifies it to the user

#### Scenario: Friendly name shown, not YAML
- **WHEN** a preset is presented to a user
- **THEN** the system shows its display name (and optional description) and does not require viewing or editing raw configuration text

### Requirement: Capture current configuration as a preset
The system SHALL create a new preset from an existing working configuration file, preserving its values and placeholder/secret references exactly.

#### Scenario: Seed from existing config
- **WHEN** the owner captures an existing working `config.yml` as a preset
- **THEN** the system creates a preset whose configuration matches that file

#### Scenario: Secret references preserved
- **WHEN** the captured configuration contains `{{env.*}}` or other placeholder references
- **THEN** the preset stores those references verbatim and does not store resolved secret values

### Requirement: Owner manages the preset library
The system SHALL let the technical owner create, rename, duplicate, edit, and delete presets.

#### Scenario: Create and edit
- **WHEN** the owner creates or edits a preset
- **THEN** the system persists the resulting preset in the preset library

#### Scenario: Duplicate as a starting point
- **WHEN** the owner duplicates an existing preset
- **THEN** the system creates an independent copy that can be edited without affecting the original

#### Scenario: Delete
- **WHEN** the owner deletes a preset
- **THEN** the system removes it from the library and it is no longer selectable

### Requirement: Cutter selects a preset per episode
The system SHALL let a non-technical cutter choose a preset for an episode from a list of presets, without editing configuration text or environment variables.

#### Scenario: Pick from a list
- **WHEN** the cutter prepares an episode
- **THEN** the system offers the available presets by display name and records the chosen preset with the episode

#### Scenario: Selection persists with the episode
- **WHEN** an episode with a selected preset is reopened
- **THEN** the system shows the same preset selection

### Requirement: Export and import a preset bundle
The system SHALL let the owner export the preset library (all presets or a selected subset) to a single shareable bundle file, and SHALL let another user import that bundle into their app, adding the contained presets to their library in one step without manual configuration. Imported bundles SHALL preserve placeholder/secret references verbatim and SHALL NOT contain resolved secret values.

#### Scenario: Owner exports a bundle
- **WHEN** the owner exports presets
- **THEN** the system writes a single bundle file containing the selected presets and their configurations

#### Scenario: Cutter imports a bundle
- **WHEN** the cutter imports a preset bundle
- **THEN** the system adds the contained presets to the cutter's library and they become selectable without further setup

#### Scenario: Import resolves name/id collisions
- **WHEN** an imported preset collides with an existing preset id or display name
- **THEN** the system reconciles the collision without silently discarding either preset (e.g. by importing as a distinct copy)

#### Scenario: No secrets in the bundle
- **WHEN** a preset referencing `{{env.*}}` is exported
- **THEN** the bundle stores the reference verbatim and contains no resolved secret value

### Requirement: Default preset guarantees a valid configuration
The system SHALL designate one preset as the default and apply it to any episode that has no explicit preset selection, so every episode has a valid configuration to run with.

#### Scenario: No explicit choice
- **WHEN** an episode is run without an explicit preset selection
- **THEN** the system applies the default preset

### Requirement: Applying a preset runs podflow with that configuration
The system SHALL ensure that when podflow runs for an episode, the CLI loads the selected preset's configuration for that run, without the cutter managing config files or environment variables, and without overwriting the user's global configuration.

#### Scenario: Run uses the selected preset
- **WHEN** podflow is run for an episode with a selected preset
- **THEN** the CLI executes using that preset's configuration

#### Scenario: Global config untouched
- **WHEN** a preset is applied for an episode run
- **THEN** the user's global `config.yml` is not overwritten by the application step

#### Scenario: Concurrent episodes with different presets
- **WHEN** two episodes with different selected presets are run
- **THEN** each run uses its own preset's configuration without interfering with the other

### Requirement: Invalid presets cannot be applied
The system SHALL validate that a preset parses into a complete podflow configuration before it is applied, and SHALL prevent applying a preset that does not.

#### Scenario: Invalid preset blocked
- **WHEN** a preset fails to parse into a valid podflow configuration
- **THEN** the system does not run podflow with it and reports the problem to the user
