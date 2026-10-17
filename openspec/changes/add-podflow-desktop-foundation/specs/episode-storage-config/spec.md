# Spec Delta

## Purpose

Lets the user configure a single on-machine root folder under which each podcast episode lives in its own subfolder, so the app can discover episodes and run podflow in the correct directory.

## ADDED Requirements

### Requirement: Configurable storage root
The app SHALL let the user choose and persist a storage root folder on the local machine, and SHALL use it as the base for discovering episodes and running podflow. The root SHALL persist across restarts.

#### Scenario: User sets the storage root
- **WHEN** the user selects a folder as the storage root
- **THEN** the app persists that path and uses it for subsequent episode discovery

#### Scenario: Root persists across restarts
- **WHEN** the app is relaunched after a storage root was set
- **THEN** the app continues to use the previously chosen root without re-prompting

### Requirement: Episodes discovered as subfolders
The app SHALL treat each immediate subfolder of the storage root as an episode working directory and SHALL present discoverable episodes from those subfolders.

#### Scenario: Subfolders listed as episodes
- **WHEN** the storage root contains episode subfolders
- **THEN** the app lists each subfolder as a candidate episode

#### Scenario: Empty or missing root
- **WHEN** the storage root is empty, unset, or no longer exists
- **THEN** the app shows an empty/needs-configuration state rather than failing

### Requirement: Podflow runs in the selected episode directory
When running podflow for an episode, the app SHALL invoke it with the working directory set to that episode's subfolder under the storage root.

#### Scenario: Correct working directory
- **WHEN** the user triggers podflow for a selected episode
- **THEN** the app runs the podflow binary with its working directory set to that episode's subfolder
