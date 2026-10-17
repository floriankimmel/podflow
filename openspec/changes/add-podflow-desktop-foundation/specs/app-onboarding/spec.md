# Spec Delta

## Purpose

A guided first-run onboarding flow that detects, installs, and verifies the external tools podflow needs and configures the storage root, so non-technical users reach a working setup without using a terminal.

## ADDED Requirements

### Requirement: Detect required dependencies
The onboarding SHALL check for the presence of each required external dependency (pi coding agent, Ollama, the parakeet model, and the podflow CLI) and SHALL present each one's detection status to the user.

#### Scenario: Dependency already installed
- **WHEN** a required dependency is already present on the machine
- **THEN** onboarding marks it as detected and does not reinstall it

#### Scenario: Dependency missing
- **WHEN** a required dependency is not found
- **THEN** onboarding marks it as missing and offers to install it

### Requirement: Guided installation of missing dependencies
The onboarding SHALL install missing dependencies on the user's confirmation, showing progress and a clear success or failure result for each, without requiring the user to run terminal commands.

#### Scenario: User confirms install
- **WHEN** the user confirms installing a missing dependency
- **THEN** onboarding performs the installation, shows progress, and reports success or a actionable failure

#### Scenario: Installation fails
- **WHEN** an installation step fails
- **THEN** onboarding surfaces the failure with guidance and does not report the setup as complete

### Requirement: Download the transcription model
The onboarding SHALL be able to download the parakeet model used for transcription via Ollama as part of provisioning, treating it as a potentially large, resumable step with visible progress.

#### Scenario: Model download
- **WHEN** the parakeet model is missing and the user proceeds
- **THEN** onboarding downloads the model through Ollama and shows download progress until it is available

### Requirement: Configure storage root during onboarding
The onboarding SHALL prompt the user to choose the episode storage root and SHALL persist it, so the app has a working directory base when onboarding completes.

#### Scenario: Storage root chosen in onboarding
- **WHEN** the user selects a storage root during onboarding
- **THEN** onboarding persists it and marks the storage step complete

### Requirement: Completion reflects readiness
The onboarding SHALL report completion only when the dependencies required for the available features and the storage root are in place, and SHALL allow the user to re-run onboarding later to finish staged steps.

#### Scenario: Ready for publish and visualization
- **WHEN** the podflow CLI is installed and the storage root is configured
- **THEN** onboarding marks the publish/visualization setup as ready even if transcription tools are not yet installed

#### Scenario: Re-run onboarding
- **WHEN** the user re-opens onboarding after an earlier partial setup
- **THEN** onboarding re-checks all dependencies and lets the user complete the remaining steps
