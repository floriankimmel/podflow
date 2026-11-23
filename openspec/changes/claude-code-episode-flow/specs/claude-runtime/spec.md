# Spec Delta

## Purpose

The app runs all episode work through Claude Code and the `podflow` plugin it ships with, and sets Claude Code up automatically so a non-technical user never touches a terminal.

## ADDED Requirements

### Requirement: Install Claude Code when missing
The app SHALL detect whether the `claude` CLI is installed on start and, if missing, install it with the official native installer while showing progress.

#### Scenario: Claude Code missing
- **WHEN** the app starts and no `claude` binary is found
- **THEN** the app runs the native installer, shows progress, and continues onboarding when it succeeds

#### Scenario: Install fails
- **WHEN** the installer exits with an error
- **THEN** the app shows the error with a retry action and does not allow starting an episode run

### Requirement: Guide Claude login
The app SHALL detect whether Claude Code is logged in and guide the user through the browser login with their own Claude account.

#### Scenario: Not logged in
- **WHEN** Claude Code is installed but not authenticated
- **THEN** the app starts the login flow, which opens the browser, and re-checks authentication when the user returns

### Requirement: Ship the podflow plugin with the app
The app bundle SHALL contain the `podflow` plugin and load it for every run with `--plugin-dir`, without installing anything into the user's Claude Code.

#### Scenario: Fresh machine
- **WHEN** a user who never installed a Claude Code plugin starts an episode run
- **THEN** the run uses the plugin from the app bundle without any install step

#### Scenario: App update
- **WHEN** the app is updated to a version with changed skills
- **THEN** the next run uses the new skills

### Requirement: Run plugin skills headless
The app SHALL run plugin skills via `claude -p` with `--plugin-dir`, `--output-format stream-json` and `--dangerously-skip-permissions`, with the episode folder as working directory and secrets passed as environment variables, and render streamed progress.

#### Scenario: Run streams progress
- **WHEN** the app starts a `prepare` or `publish` run for an episode
- **THEN** the app spawns `claude -p` in the episode folder, shows step progress from the stream, and writes the raw stream to `run.log`

#### Scenario: Run fails
- **WHEN** the Claude process exits non-zero or a step reports failure
- **THEN** the app marks the run failed, shows the failing step and error, and offers retry
