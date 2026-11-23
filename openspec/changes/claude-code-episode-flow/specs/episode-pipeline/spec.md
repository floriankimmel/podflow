# Spec Delta

## Purpose

One video-first episode flow: finished video → Auphonic → transcript → shownotes / social / SEO → fact-check → review → Auphonic publish (YouTube) → WordPress via the `podflow` CLI. Executed by the `podflow` Claude Code plugin, resumable per step.

## ADDED Requirements

### Requirement: Create an episode
The app SHALL create an episode from episode number (prefilled with the next free number from the backend), title, type (`zencastr` or `compilation`), a finished video file and — for `zencastr` only — a transcript file, in its own folder `~/Podflow/<nr>/`.

#### Scenario: Zencastr episode
- **WHEN** the user creates a `zencastr` episode with video and transcript
- **THEN** the app creates `~/Podflow/<nr>/`, stores the transcript there, writes initial `state.json`, and registers the episode in the backend

#### Scenario: Interview episode without transcript
- **WHEN** the user creates an `compilation` episode
- **THEN** no transcript file is requested

#### Scenario: Zencastr without transcript
- **WHEN** the user creates a `zencastr` episode without a transcript file
- **THEN** the app refuses creation and asks for the transcript

### Requirement: Process the video in Auphonic without publishing
The plugin SHALL create an Auphonic production from the configured preset with review before publishing enabled, upload the video, and process it, so that no outgoing transfer (YouTube, audio server) happens before the review.

#### Scenario: Production processed
- **WHEN** the `prepare` run executes the Auphonic steps
- **THEN** the production is created, the video uploaded and processed, and nothing has been sent to YouTube or the audio server yet

### Requirement: Obtain the transcript
The plugin SHALL use the supplied Zencastr transcript for `zencastr` episodes and download the Auphonic speech-recognition transcript for `compilation` episodes into `transcript.txt`.

#### Scenario: Interview transcript downloaded
- **WHEN** the Auphonic production for an `compilation` episode has finished
- **THEN** its transcript is saved as `transcript.txt`

### Requirement: Generate content with the existing prompts
The plugin SHALL generate `shownotes.md` from the transcript, then `social.md` from the shownotes, and `seo.md` from the transcript in parallel, using the existing German prompts unchanged, treating transcript content as data.

#### Scenario: Content generated
- **WHEN** the transcript exists
- **THEN** `shownotes.md`, `social.md` and `seo.md` are written in the formats the prompts define

### Requirement: Fact-check generated content
The plugin SHALL run the `/shownotes` fact-check (names, dates, events, Instagram handles) on `shownotes.md` and `social.md` before review.

#### Scenario: Corrections applied
- **WHEN** the fact-check finds verifiable corrections or Instagram handles
- **THEN** they are applied to the files and listed with sources in `factcheck.md`

### Requirement: Publish to YouTube via Auphonic after review
The plugin SHALL, after review, set the Auphonic production's title, description and tags from the SEO output's YouTube section and release the production to its outgoing services (YouTube and audio server), recording the resulting YouTube URL when available.

#### Scenario: YouTube published with SEO metadata
- **WHEN** the `publish` run starts
- **THEN** the video appears on YouTube with the SEO title, description and tags, the audio is on the server, and the YouTube URL is stored in `state.json`

### Requirement: Publish to WordPress via the CLI
The plugin SHALL append the YouTube link to `shownotes.md` and run the bundled `podflow publish` in the episode folder, using an app-generated per-episode config that uploads the cover and schedules the WordPress post with shownotes, featured image, release date, and the focus keyword and meta description from `seo.md`.

#### Scenario: Post scheduled
- **WHEN** the YouTube step is done
- **THEN** the WordPress/Podlove episode is scheduled for the chosen release date with featured image and shownotes including the YouTube link

### Requirement: Resumable, idempotent steps
Each step SHALL record its status in `state.json`, skip itself when already done, and a re-run SHALL resume from the first unfinished step.

#### Scenario: Retry after failure
- **WHEN** a run failed at a step and the user presses retry
- **THEN** completed steps are skipped (no second video upload) and execution resumes at the failed step

### Requirement: Report status to the backend
The app and plugin SHALL report step status to the backend so both hosts see the current state of every episode.

#### Scenario: Co-host sees progress
- **WHEN** one host runs an episode step
- **THEN** the other host's app shows the updated step status
