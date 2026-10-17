# Proposal

## Why

Our second cutter works video-first: they start from a finished cut video, upload it to Auphonic (which publishes the video to YouTube and the audio to our server), then write shownotes/social/SEO by hand. This change brings that workflow into the app as a second episode profile, so both cutters share one episode model, one state/visualization, and the same local transcription + generation + publish pipeline — replacing the manual Copilot/Word steps.

It builds on `add-podflow-desktop-foundation` (episode folder, backend, profiles, flow visualization) and reuses `add-transcription-content-generation` (local transcription + shownotes/social/SEO).

## What Changes

- Add a **Video/Auphonic ingest**: the app uploads a finished video to Auphonic and triggers the Auphonic production that publishes the video to YouTube and the audio to our server.
- Add a **server audio download** that pulls the produced audio into a **new episode folder with the same structure** as the studio workflow — minus the `Recordings/` and Reaper project (no Reaper production).
- Introduce the **Video/Auphonic profile**: pipeline stages Video → Auphonic (YouTube + server) → Download audio → Transcribe → Shownotes → Social → SEO → Publish, where **Publish excludes the Auphonic step** (already done up front).
- Feed the generated **YouTube/video description** (from the SEO prompt's YouTube output) into the Auphonic metadata when available; otherwise it can be filled later — removing the fixed "Auphonic-first vs content-first" ordering.
- After this, downstream is identical to the studio workflow: local transcription, generation, podflow publish, and manual social posting with reminders.

Out of scope: Reaper production for this profile (there is none), automated posting to the individual social networks (stays manual), and importing an external Zencastr/Word transcript (transcription stays local-only).

## Capabilities

### New Capabilities
- `auphonic-video-ingest`: upload a finished video to Auphonic, trigger its YouTube + server-audio production, and download the produced audio into a new episode folder matching the standard structure (no Reaper), under the Video/Auphonic profile.

### Modified Capabilities
<!-- None as spec deltas here: the Video/Auphonic profile plugs into the profile mechanism and
     flow visualization introduced by add-podflow-desktop-foundation, and reuses the transcription
     and content-generation capabilities. Those changes are not yet archived into openspec/specs/,
     so they are referenced as dependencies rather than modified. -->

## Impact

- **Desktop app**: a Video/Auphonic new-episode path (pick video → Auphonic → server download), and the Video/Auphonic profile wired into the flow view.
- **Auphonic**: used up front for production/distribution (video→YouTube, audio→server), configured via the existing Auphonic credentials/presets.
- **Server**: the app downloads the produced audio from our server into the episode folder.
- **Publish**: the Video/Auphonic profile runs podflow without the Auphonic step.
- **Depends on**: `add-podflow-desktop-foundation` (profiles, episode folder, backend, flow viz) and `add-transcription-content-generation` (local transcription + generation).
