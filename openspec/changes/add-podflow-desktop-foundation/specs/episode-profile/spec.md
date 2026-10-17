# Spec Delta

## Purpose

Gives each episode a profile that selects its ordered pipeline stages and which publish steps run, so different production workflows (studio/Reaper and video/Auphonic) share one episode, state, and visualization model.

## ADDED Requirements

### Requirement: Episode has a profile
The system SHALL assign each episode a profile, chosen at creation and stored with the episode, that determines the episode's pipeline. At least the Studio/Reaper profile SHALL be available.

#### Scenario: Profile chosen at creation
- **WHEN** a new episode is created
- **THEN** the system records the selected profile with the episode

#### Scenario: Default profile
- **WHEN** no profile is explicitly chosen
- **THEN** the system assigns the Studio/Reaper profile

### Requirement: Profile defines the pipeline stages
The system SHALL derive an episode's ordered pipeline stages from its profile, and the flow visualization SHALL render exactly those stages in that order.

#### Scenario: Stages come from the profile
- **WHEN** an episode is displayed
- **THEN** the flow visualization shows the ordered stages defined by that episode's profile

#### Scenario: Different profiles, different stages
- **WHEN** two episodes have different profiles
- **THEN** each shows the stage set and order defined by its own profile

### Requirement: Profile selects which publish steps run
The system SHALL run only the publish steps included by an episode's profile, so a profile can include or exclude a given step (for example, excluding the Auphonic step when it was already handled upstream).

#### Scenario: Excluded step is skipped
- **WHEN** an episode's profile excludes a publish step
- **THEN** publish does not run that step and does not report it as pending work

#### Scenario: Included steps run
- **WHEN** an episode's profile includes a publish step
- **THEN** publish runs that step as normal
