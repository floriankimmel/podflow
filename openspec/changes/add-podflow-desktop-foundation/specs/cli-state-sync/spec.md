# Spec Delta

## Purpose

Teaches the podflow CLI to report episode publish progress to the shared backend during `publish`, so remote observers see live per-step status while keeping local operation functional when the backend is unreachable.

## ADDED Requirements

### Requirement: Report step transitions during publish
The CLI SHALL report each publish step's transition (start, success, failure) to the backend as the `publish` command executes, using the configured backend URL and workspace credential.

#### Scenario: Step starts
- **WHEN** the CLI begins executing a publish step for an episode
- **THEN** the CLI reports that step as in-progress to the backend

#### Scenario: Step succeeds
- **WHEN** a publish step completes successfully
- **THEN** the CLI reports that step as done to the backend

#### Scenario: Step fails
- **WHEN** a publish step returns an error
- **THEN** the CLI reports that step as failed to the backend before terminating the publish run

### Requirement: Report episode identity and metadata
The CLI SHALL include a stable episode identity plus metadata (episode number, title, release date) with its reports, so the backend can create or update the correct episode record.

#### Scenario: Metadata accompanies reports
- **WHEN** the CLI reports any step status for an episode
- **THEN** the report carries the episode identity and known metadata so the backend upserts the matching record

### Requirement: Local operation resilient to backend outages
The CLI SHALL continue to execute the publish pipeline and update local `state.yml` even when the backend is unreachable or rejects a report. A failed state report SHALL NOT abort a successful publish step.

#### Scenario: Backend unreachable
- **WHEN** the CLI cannot reach the backend while reporting a step
- **THEN** the CLI logs a warning, continues the publish pipeline, and still updates local state

#### Scenario: Backend reporting disabled
- **WHEN** no backend URL or workspace credential is configured
- **THEN** the CLI runs publish exactly as before without attempting to report

### Requirement: Local state remains the working record
The CLI SHALL keep writing `{{folder}}.state.yml` as its local working record; backend reporting is additive and SHALL NOT replace local state persistence.

#### Scenario: Local state still written
- **WHEN** a publish step succeeds with backend reporting enabled
- **THEN** the CLI writes the step result to local `state.yml` as it does today, in addition to reporting to the backend
