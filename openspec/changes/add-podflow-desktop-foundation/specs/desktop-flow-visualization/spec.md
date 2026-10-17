# Spec Delta

## Purpose

A native macOS app that authenticates to the shared workspace and renders a live visualization of where an episode currently sits in the publish pipeline, reading authoritative state from the backend.

## ADDED Requirements

### Requirement: Authenticate to shared workspace
The app SHALL let the user configure the backend URL and shared workspace credential, and SHALL use them for all backend requests. The app SHALL surface an error state when the credential is missing or rejected.

#### Scenario: Valid credential configured
- **WHEN** the user has entered a valid backend URL and workspace credential
- **THEN** the app loads the workspace's episodes from the backend

#### Scenario: Missing or rejected credential
- **WHEN** the credential is absent or the backend rejects it
- **THEN** the app shows an authentication error instead of episode data

### Requirement: Display episode list from backend
The app SHALL display the list of episodes in the shared workspace with their metadata, sourced from the backend so it matches what other clients see.

#### Scenario: Episodes listed
- **WHEN** the workspace contains episodes
- **THEN** the app lists each episode with its number, title, and release date

#### Scenario: Long title does not overflow
- **WHEN** an episode title is too long to fit its row
- **THEN** the app truncates the title with an ellipsis within the row bounds and never lets text overflow under the pane edge

### Requirement: Visualize publish pipeline progress
The app SHALL render the publish pipeline as an ordered sequence of stages (FTP delete, FTP upload, Download, S3, WordPress, Steady, Auphonic) and SHALL indicate each stage's status (pending, in-progress, done, failed) for the selected episode based on backend state.

#### Scenario: Selecting an episode shows its flow
- **WHEN** the user selects an episode
- **THEN** the app shows every pipeline stage with a visual status reflecting the episode's current per-step status

#### Scenario: Live progress reflected
- **WHEN** the backend state for the selected episode changes while it is displayed
- **THEN** the app updates the stage statuses to match without requiring a restart

#### Scenario: Failed stage is distinguishable
- **WHEN** a stage is reported as failed
- **THEN** the app renders that stage in a visually distinct failed state

### Requirement: Shared state parity
The app SHALL present the same episode state that any other authorized client sees, because it reads from the backend source of truth rather than any local-only file.

#### Scenario: Matches other observers
- **WHEN** two app instances with the same workspace credential view the same episode
- **THEN** both show the same per-step statuses

### Requirement: Pre-publish readiness check
The app SHALL show whether an episode has the required files present before publishing (edited mp3 and m4a, chapters, cover art image, shownotes, and the SEO content file) and SHALL indicate any that are missing.

#### Scenario: All required files present
- **WHEN** an episode folder contains all required files
- **THEN** the app shows the episode as ready to publish

#### Scenario: Missing file surfaced
- **WHEN** a required file (for example the cover art) is missing
- **THEN** the app shows the episode as not ready and names the missing file

### Requirement: Post-publish manual follow-up reminder
The app SHALL surface a reminder for manual follow-up steps after a successful publish, including the manual Patreon upload.

#### Scenario: Reminder after publish
- **WHEN** publish completes successfully
- **THEN** the app shows a reminder to perform the manual Patreon upload
