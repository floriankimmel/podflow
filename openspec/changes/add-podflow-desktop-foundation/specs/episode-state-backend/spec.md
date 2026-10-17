# Spec Delta

## Purpose

A fly.io-hosted HTTP API that is the single source of truth for shared podcast episode publish state, scoped to one shared team workspace so every authorized client sees identical episodes and per-step status.

## ADDED Requirements

### Requirement: Shared workspace authentication
The API SHALL require a shared workspace credential on every request and SHALL reject unauthenticated or invalid-credential requests. All requests presenting the valid workspace credential operate on the same single shared workspace.

#### Scenario: Request with valid workspace key
- **WHEN** a client calls any episode endpoint with the valid workspace credential
- **THEN** the API processes the request against the shared workspace

#### Scenario: Request without a valid credential
- **WHEN** a client calls any endpoint with a missing or invalid credential
- **THEN** the API responds with an authentication error and performs no read or write

### Requirement: Episode records are the source of truth
The API SHALL store and serve episode records identified by a stable episode identity, including episode metadata (number, title, release date) and per-step publish status. A stored record is authoritative for shared viewing.

#### Scenario: List episodes
- **WHEN** an authenticated client requests the episode list
- **THEN** the API returns all episodes in the workspace with their metadata and current per-step status

#### Scenario: Fetch a single episode
- **WHEN** an authenticated client requests an episode by its identity
- **THEN** the API returns that episode's metadata and per-step status, or a not-found error if it does not exist

### Requirement: Per-step publish status storage
The API SHALL persist a per-step status for each publish stage (FTP delete, FTP upload, Download, S3, WordPress, Steady, Auphonic). Each step status SHALL be one of a defined set that distinguishes at least pending, in-progress, done, and failed.

#### Scenario: Update a step status
- **WHEN** an authenticated client reports a step transition for an episode
- **THEN** the API persists the new step status and the updated record is returned on subsequent reads

#### Scenario: Unknown step rejected
- **WHEN** a client reports status for a step name outside the defined set
- **THEN** the API responds with a validation error and does not alter stored state

### Requirement: Episode upsert on first report
The API SHALL create an episode record when a client reports state for an episode identity that does not yet exist, and SHALL update the existing record otherwise, so the CLI can report without a separate create call.

#### Scenario: First report creates the record
- **WHEN** a client reports metadata/step status for an episode identity not present in the workspace
- **THEN** the API creates the episode record with the reported values

#### Scenario: Subsequent report updates the record
- **WHEN** a client reports for an episode identity that already exists
- **THEN** the API updates the existing record rather than creating a duplicate

### Requirement: Consistent shared view
The API SHALL serve the most recently persisted state to all authorized clients, so independent observers see the same episode state after a report is acknowledged.

#### Scenario: Two observers see identical state
- **WHEN** one client's step report has been acknowledged and two other clients fetch the episode
- **THEN** both clients receive the same metadata and per-step status reflecting that report
