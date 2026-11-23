# Spec Delta

## Purpose

A mandatory human review between content generation and publishing, where the host edits content, copies manual-only parts, and supplies image and release date.

## ADDED Requirements

### Requirement: Review generated content before publishing
The app SHALL show a review screen after the `prepare` run completes and SHALL NOT publish anything until the user confirms it.

#### Scenario: Prepare finished
- **WHEN** the `prepare` run completes successfully
- **THEN** the episode enters the review state and the review screen is available

### Requirement: Edit shownotes
The app SHALL let the user edit `shownotes.md` and save changes back to the episode folder before publishing.

#### Scenario: Edited shownotes are published
- **WHEN** the user edits shownotes and presses Publish
- **THEN** the edited text is what gets published

### Requirement: SEO with copy buttons
The app SHALL display each SEO section (title tag, meta description, focus keywords, OG title/description, YouTube title/description/tags) with a copy button for manual entry in WordPress/Yoast.

#### Scenario: Copy meta description
- **WHEN** the user presses copy on the meta description
- **THEN** exactly that section's text is on the clipboard

### Requirement: Social media cards
The app SHALL show one editable card with a copy button for each platform in `social.md` (Discord, LinkedIn, Instagram, Strava, Facebook, YouTube).

#### Scenario: Copy edited post
- **WHEN** the user edits the Instagram card and presses copy
- **THEN** the edited Instagram text is on the clipboard and saved to `social.md`

### Requirement: Featured image and release date
The app SHALL require a featured image and a release date/time before Publish is enabled, and pass both into the episode's `config.yml`.

#### Scenario: Missing image
- **WHEN** no featured image is selected
- **THEN** Publish is disabled with a hint
