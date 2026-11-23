# Spec Delta

## Purpose

The app is installable and updatable by a non-technical user and ships everything it needs except Claude Code itself.

## ADDED Requirements

### Requirement: Bundle the podflow CLI
The app bundle SHALL contain a `podflow` CLI binary built from this repository and pass its path to plugin runs.

#### Scenario: Publish without separate CLI install
- **WHEN** a user without a separately installed `podflow` CLI publishes an episode
- **THEN** the bundled binary is used

### Requirement: Signed, notarized releases with auto-update
The app SHALL be distributed as a Developer ID signed and notarized `.dmg` via GitHub Releases and update itself via Sparkle.

#### Scenario: First launch
- **WHEN** a user opens the downloaded app for the first time
- **THEN** macOS opens it without Gatekeeper warnings

#### Scenario: New version available
- **WHEN** a newer release is published
- **THEN** the app offers to update in place

### Requirement: Onboarding of shared credentials
The app SHALL collect Auphonic credentials, Auphonic preset UUID, WordPress API key and workspace key in onboarding, store secrets in the Keychain, and pass them only as environment variables to runs.

#### Scenario: Secrets never written to episode files
- **WHEN** an episode `config.yml` is generated
- **THEN** it references secrets as `{{env.*}}` and contains no secret values

## REMOVED Requirements

### Requirement: Legacy desktop features
Studio/Reaper profiles, Reaper project generation, Dropbox/Zencastr folder ingest, local Ollama generation, local quicksubs/Parakeet transcription and dependency installation, config presets, server audio download and the server audio URL template are removed from the app.

#### Scenario: Only the Claude Code flow remains
- **WHEN** a user opens the app
- **THEN** only the episode flow described in this change is available
