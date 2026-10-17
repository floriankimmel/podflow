# Spec Delta

## Purpose

Produces a text transcript from an episode's audio using a local engine (quicksubs with the parakeet model via Ollama), persisting it as a stateful, re-runnable step so later generation and publish can rely on it.

## ADDED Requirements

### Requirement: Transcribe episode audio locally
The system SHALL generate a transcript from an episode's primary audio file using the local transcription engine, without uploading audio to a remote service.

#### Scenario: Audio present
- **WHEN** the user starts transcription for an episode whose folder contains a supported audio file
- **THEN** the system runs local transcription and produces a transcript for that episode

#### Scenario: No audio available
- **WHEN** the episode folder contains no supported audio file
- **THEN** the system reports a clear error and does not mark transcription as done

### Requirement: Required engine must be available
The system SHALL verify that the transcription engine and model (Ollama + parakeet) are available before running, and SHALL direct the user to onboarding when they are missing.

#### Scenario: Engine missing
- **WHEN** transcription is requested but Ollama or the parakeet model is not installed
- **THEN** the system reports the missing dependency and points the user to onboarding rather than failing silently

### Requirement: Persist the transcript
The system SHALL write the transcript to the episode folder and record its availability in the backend, so it is reusable locally and visible to shared observers.

#### Scenario: Transcript stored
- **WHEN** transcription completes successfully
- **THEN** the transcript file exists in the episode folder and the backend records the transcription step as done

### Requirement: Transcription is a re-runnable stateful step
The system SHALL treat transcription as a stateful step that is skipped when already complete and can be explicitly re-run to overwrite the prior transcript.

#### Scenario: Skip when already done
- **WHEN** a transcript already exists and the step is not forced
- **THEN** the system skips re-transcribing and reports the step as already done

#### Scenario: Forced re-run
- **WHEN** the user explicitly re-runs transcription
- **THEN** the system regenerates the transcript and updates the stored result
