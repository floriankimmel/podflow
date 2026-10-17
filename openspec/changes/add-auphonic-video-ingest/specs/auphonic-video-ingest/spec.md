# Spec Delta

## Purpose

Brings the video-first workflow into the app: upload a finished video to Auphonic (which publishes to YouTube and sends audio to our server), then download that audio into a new episode folder matching the standard structure without a Reaper production, under the Video/Auphonic profile.

## ADDED Requirements

### Requirement: Upload finished video to Auphonic
The app SHALL let the user select a finished video and start an Auphonic production for it that publishes the video to YouTube and delivers the processed audio to our server, using the configured Auphonic credentials and preset.

#### Scenario: Video uploaded and production started
- **WHEN** the user selects a finished video and starts the Video/Auphonic ingest
- **THEN** the app uploads the video to Auphonic and starts the production targeting YouTube and the audio server

#### Scenario: Auphonic unavailable or misconfigured
- **WHEN** Auphonic credentials or preset are missing or the upload fails
- **THEN** the app reports the error and does not mark the step as done

### Requirement: Create the episode folder for the Video/Auphonic profile
The app SHALL create a new episode under the storage root with the standard episode structure for downstream steps, omitting the `Recordings/` area and Reaper project, and assign the Video/Auphonic profile.

#### Scenario: Episode created without Reaper artifacts
- **WHEN** a Video/Auphonic episode is created
- **THEN** the app creates the episode folder with the standard structure but without a `Recordings/` folder or Reaper project, and records the Video/Auphonic profile

### Requirement: Download produced audio from the server
The app SHALL download the audio produced by Auphonic from our server into the episode folder, so transcription and publishing can proceed.

#### Scenario: Audio downloaded into the episode
- **WHEN** the Auphonic production has delivered audio to the server
- **THEN** the app downloads it into the episode folder and marks the download step done

#### Scenario: Audio not ready yet
- **WHEN** the produced audio is not yet available on the server
- **THEN** the app indicates the episode is awaiting produced audio and does not block the episode

### Requirement: Provide the video description to Auphonic when available
The app SHALL pass the generated YouTube/video description to the Auphonic production metadata when it exists at upload time, and otherwise allow it to be supplied later, so there is no fixed ordering between content generation and Auphonic.

#### Scenario: Description available at upload
- **WHEN** generated YouTube/video description already exists when the Auphonic production is started
- **THEN** the app includes it in the Auphonic metadata

#### Scenario: Description generated afterwards
- **WHEN** the description is generated after the Auphonic production was started
- **THEN** the app still allows the description to be applied without requiring a specific earlier order

### Requirement: Publish excludes the Auphonic step for this profile
Publishing an episode on the Video/Auphonic profile SHALL run the podflow pipeline without the Auphonic step, because Auphonic already ran during ingest.

#### Scenario: Auphonic skipped at publish
- **WHEN** a Video/Auphonic episode is published
- **THEN** the podflow run does not perform the Auphonic step and does not report it as pending work
