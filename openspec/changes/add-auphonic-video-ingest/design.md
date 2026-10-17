# Design

## Context

See proposal.md — Why. This change depends on `add-podflow-desktop-foundation` (episode folder, backend, the profile mechanism, flow visualization) and `add-transcription-content-generation` (local transcription + shownotes/social/SEO). podflow already has an Auphonic publish target (`StartAuphonicProduction`) used at publish time; here Auphonic is used **up front** for production/distribution instead.

The video-first workflow today: finished video → Auphonic (video→YouTube, audio→server) → transcript (Zencastr rename or Word) → three Copilot chats (social/SEO/shownotes) → manual paste into WordPress + socials. Two orderings exist only because the transcript is sometimes available before Auphonic and sometimes only after. Our app removes that by running stages on dependency.

## Goals / Non-Goals

**Goals:**
- A second profile that reuses the shared episode/state/pipeline, so both cutters use one tool.
- Replace the Copilot/Word steps with the app's local transcription + generation.
- Make Auphonic a front-of-pipeline stage for this profile and skip it at publish.

**Non-Goals:**
- Reaper production (none for this profile).
- Automated posting to individual social networks (stays manual).
- External transcript import (transcription stays local-only, run on the downloaded audio).

## Decisions

### D1: Auphonic up front via its API, reusing existing credentials
Start the Auphonic production from the app using the same Auphonic account/preset podflow already uses, configured to publish the video to YouTube and send audio to our server (Auphonic's outgoing targets). Rationale: one Auphonic setup; the app only orchestrates. Alternative (manual Auphonic web UI) rejected: that's the status quo we are removing.

### D2: Server download fills the episode folder
After Auphonic delivers audio to our server, the app downloads it into the episode folder as the episode audio. The episode folder uses the standard structure minus `Recordings/` and the Reaper project. Rationale: downstream (transcription, generation, publish) is folder-based and profile-agnostic, so once audio is present nothing else needs to know how it got there.

### D3: Video/Auphonic profile defines the stages and publish subset
The profile (from the foundation change) lists: Video → Auphonic(YouTube+server) → Download audio → Transcribe → Shownotes → Social → SEO → Publish. Its publish-step subset excludes Auphonic. Rationale: the profile mechanism already selects stages + publish steps; this is data, not new control flow.

### D4: Description wiring removes ordering constraints
The SEO prompt already emits a YouTube title/description/tags. The app passes that description into the Auphonic production metadata if it exists when the production starts; otherwise the user applies it later (Auphonic supports editing/updating metadata). Rationale: eliminates the manual "Auphonic-first vs content-first" decision; stages simply run when their inputs exist.

### D5: Audio delivery reuses podflow's existing audio server (FTP)
Auphonic's outgoing target delivers the produced audio to the same podcast audio server podflow already uses (its `Download`/FTP target), configured once from the existing credentials. The app downloads the audio from that same location into the episode folder. Rationale: one server, one credential set already proven in podflow; no new hosting. Alternative (separate S3/HTTP target) rejected: avoids a second storage config.

### D6: Stateful download polls for produced audio (no webhook)
The download step polls the server for the produced audio and completes when present, reusing the app's active-polling cadence; it reports "awaiting produced audio" until then. Rationale: no public webhook endpoint to host or secure; a simple poll fits the small-team scale and the existing adaptive-polling model. Alternative (Auphonic webhook) rejected: needs a reachable endpoint and adds moving parts for little gain.

## Risks / Trade-offs

- [Auphonic API/outgoing-target config drift] → reuse the proven account/preset; surface clear errors; never mark done on failure.
- [Server audio not ready when polled] → treat download as a stateful step that waits and retries; do not block the episode.
- [Two Auphonic roles (ingest here vs publish target in studio profile)] → profile selects which; Video/Auphonic excludes the publish Auphonic step to avoid double processing.
- [YouTube already published by Auphonic while app still finalizing content] → description can be updated post-publish on YouTube/Auphonic; acceptable for this workflow.

## Migration Plan

1. Land after the foundation and transcription/generation changes.
2. Ship the Video/Auphonic profile + ingest; studio workflow unaffected.
3. Rollback: hide the Video/Auphonic new-episode path; existing episodes keep working (folder-based).

## Open Questions

None.
