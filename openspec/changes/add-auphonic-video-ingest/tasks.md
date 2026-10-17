# Tasks

## 1. Video/Auphonic profile

- [ ] 1.1 Register the Video/Auphonic profile (stage set Video → Auphonic → Download → Transcribe → Shownotes → Social → SEO → Publish; publish subset excludes Auphonic); verify the flow view renders this stage set and publish skips Auphonic for the profile.

## 2. Auphonic video ingest

- [ ] 2.1 Implement video selection + Auphonic production start via the Auphonic API (reusing configured credentials/preset) targeting YouTube + the audio server; verify an integration test against a stubbed Auphonic starts a production and errors clearly when misconfigured.
- [ ] 2.2 Create the episode folder for this profile with the standard structure minus `Recordings/`/Reaper and assign the Video/Auphonic profile; verify a test creates the folder shape and records the profile.
- [ ] 2.3 Pass the generated YouTube/video description into the Auphonic metadata when present, and support applying it later when generated afterwards; verify both ordering paths in a test.

## 3. Server audio download

- [ ] 3.1 Implement a stateful download step that pulls Auphonic-produced audio from the server into the episode folder, waiting/retrying until available; verify a test downloads when ready and reports "awaiting produced audio" when not.
- [ ] 3.2 Record the download/Auphonic steps in the backend so the flow view shows live status; verify step statuses appear for a sample episode.

## 4. End-to-end integration

- [ ] 4.1 Verify the video-first loop: finished video → Auphonic (stubbed YouTube+server) → server audio download → local transcription → shownotes/social/SEO → podflow publish **without** the Auphonic step, with all stages visible in the flow view.
- [ ] 4.2 Verify both profiles coexist: a studio episode and a video episode show their own stage sets and publish behavior from the same app/backend.

## Workflow follow-up

- Archive the change after the project's review requirements are satisfied.
- Verify the archived result.
