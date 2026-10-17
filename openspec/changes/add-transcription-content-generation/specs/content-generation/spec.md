# Spec Delta

## Purpose

Generates shownotes, platform-specific social media posts, and SEO/metadata from an episode transcript using editable, prompt-driven templates, persisting results for publish and for shared viewing.

## ADDED Requirements

### Requirement: Generate shownotes from transcript
The system SHALL generate episode shownotes from the transcript using the shownotes prompt, detecting the episode type (interview vs host-conversation) and producing Markdown output only.

#### Scenario: Shownotes produced
- **WHEN** the user generates shownotes for an episode with an available transcript
- **THEN** the system produces Markdown shownotes following the active shownotes prompt and stores them for the episode

#### Scenario: Missing transcript
- **WHEN** shownotes generation is requested but no transcript exists
- **THEN** the system reports that transcription is required and does not produce output

### Requirement: Generate platform social posts
The system SHALL generate social media posts for each supported platform (Discord, LinkedIn, Instagram, Strava, Facebook, YouTube) from the shownotes using the social prompt.

#### Scenario: Social posts produced
- **WHEN** the user generates social posts and shownotes are available
- **THEN** the system produces one post per supported platform following the active social prompt

### Requirement: Generate SEO and platform metadata
The system SHALL generate SEO/metadata from the shownotes or transcript using the SEO prompt, including website title/description/keywords, Facebook Open Graph fields, and YouTube title/description/tags.

#### Scenario: SEO produced
- **WHEN** the user generates SEO metadata with content available
- **THEN** the system produces the website, Facebook, and YouTube metadata following the active SEO prompt

### Requirement: Prompts are editable and persisted
The system SHALL let the user view and edit the generation prompts in a Markdown editor, persist edits, and use the edited prompts on the next generation run.

#### Scenario: Edited prompt used
- **WHEN** the user edits a generation prompt and saves it
- **THEN** the next generation run for that artifact uses the edited prompt text

#### Scenario: Prompt placeholders filled
- **WHEN** a prompt contains placeholders such as episode number or transcript
- **THEN** the system substitutes the actual values before running the prompt

### Requirement: Generated artifacts are editable
The system SHALL let the user edit a generated artifact (shownotes and social posts) in a Markdown editor after generation, persist the edit, and use the edited version for downstream steps and publishing.

#### Scenario: Edit generated shownotes
- **WHEN** the user edits the generated shownotes and saves
- **THEN** the system persists the edited shownotes and uses them for publishing and for generating dependent artifacts

#### Scenario: Edit survives without regeneration
- **WHEN** the user has edited a generated artifact and does not re-run its generation step
- **THEN** the edited version is retained rather than being overwritten

### Requirement: Persist generated artifacts
The system SHALL write generated artifacts to the episode folder for publish and record them in the backend for shared viewing, each as a stateful, re-runnable step.

#### Scenario: Artifact stored
- **WHEN** a generation step completes successfully
- **THEN** the artifact file exists in the episode folder and the backend records that generation step as done

#### Scenario: Regenerate on demand
- **WHEN** the user re-runs a generation step
- **THEN** the system regenerates that artifact and updates the stored result without requiring the other steps to re-run

### Requirement: Artifacts stored in a podflow-readable form
The system SHALL write shownotes and SEO/content artifacts to the episode folder in the file locations and formats the podflow CLI consumes, so `publish` can use them without manual conversion.

#### Scenario: Shownotes file consumable by podflow
- **WHEN** shownotes are generated
- **THEN** they are written as a Markdown file at the episode's configured shownotes path, so podflow's WordPress/Steady steps read it directly

#### Scenario: SEO content file matches podflow's parser
- **WHEN** SEO/metadata is generated
- **THEN** it is written as the podflow content file containing `**Meta-Description:**` and `**Focus Keywords:**` lines that podflow parses, with the path honoring the `{{episodeNumber}}` placeholder convention
