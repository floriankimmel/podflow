# Spec Delta

## Purpose

Creates a new, self-contained episode under the storage root from Zencastr recordings: copies the recordings in, builds and opens the Reaper editing project inside the episode folder. Audio editing and export stay manual.

## ADDED Requirements

### Requirement: Create episode from Zencastr recordings
The app SHALL create a new episode by selecting a Zencastr episode source, enumerating every `recording-*` subfolder it contains, creating a new subfolder under the storage root, and copying the recording audio from all recordings into a `Recordings` area inside that episode folder.

#### Scenario: Recordings copied into a new episode
- **WHEN** the user selects a Zencastr episode source and names the new episode
- **THEN** the app creates a new subfolder under the storage root and copies the recording audio into a `Recordings` area inside it

#### Scenario: All recording-N aggregated
- **WHEN** the Zencastr episode source contains multiple `recording-*` subfolders
- **THEN** the app includes the audio from every `recording-*` subfolder in the new episode, not just the first

#### Scenario: New episode is discoverable
- **WHEN** the new episode subfolder has been created
- **THEN** the app lists it as an episode under the storage root

### Requirement: Build and open the editing project in the episode folder
The app SHALL generate the Reaper editing project inside the episode folder with one track per speaker, placing each matched source recording on its speaker's track as a full-length timeline item that references the file by its relative `Recordings/` path, and SHALL open the project. The project and its source audio are self-contained within the episode folder.

#### Scenario: Project generated and opened
- **WHEN** a new episode has been created from recordings
- **THEN** the app generates the Reaper project inside the episode folder with one track per speaker, each speaker's recordings placed as timeline items, and opens it

#### Scenario: Speakers mapped to tracks
- **WHEN** recordings include the known speakers (Peter via `laufendentdecken`, Florian via `florian`) and a guest
- **THEN** the app creates the Peter and Florian tracks and a third/guest track, assigning each recording to the matching track

#### Scenario: Unrecognized speaker track
- **WHEN** a recording's speaker matches none of the configured speakers
- **THEN** the app assigns it to the guest track rather than failing

### Requirement: Derive episode identity from the source
The app SHALL derive the episode number from the Zencastr source when it is available (for example, from the source folder name), and otherwise prompt the user.

#### Scenario: Number present in source
- **WHEN** the Zencastr source path encodes an episode number
- **THEN** the app pre-fills that episode number for the new episode

### Requirement: Audio editing and export are external
The app SHALL treat final audio editing and export (to mp3 and m4a) as a manual, external step in Reaper, and SHALL detect the finished audio in the episode folder for downstream transcription and publishing.

#### Scenario: Finished audio detected
- **WHEN** final mp3 and m4a files are present in the episode folder after external editing
- **THEN** the app recognizes them as the episode's audio for downstream steps

#### Scenario: Finished audio missing
- **WHEN** the edited audio is not present yet
- **THEN** the app indicates the episode is awaiting edited audio and does not block creation
