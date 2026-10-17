# Proposal

## Why

The desktop foundation (`add-podflow-desktop-foundation`) covers shared state and publish-flow visualization, but the manual pre-publish work still happens by hand: transcribing the episode and writing shownotes, social posts, and SEO metadata. This change adds the automated content pipeline — local transcription plus prompt-driven generation — so an episode goes from raw audio to ready-to-publish text inside the app.

This builds on the foundation slice: it reuses the configured storage root (episodes as subfolders), the backend as source of truth, and the onboarding-provisioned tools (Ollama + parakeet model, pi coding agent).

## What Changes

- Add **local transcription**: produce a transcript from an episode's audio using quicksubs with the local parakeet model via Ollama. Transcript is written to the episode folder and recorded in the backend.
- Add **content generation**: from the transcript, generate **shownotes**, **social media posts** (Discord, LinkedIn, Instagram, Strava, Facebook, YouTube), and **SEO/metadata** (website title/description/keywords, Facebook OG, YouTube title/description/tags). Generation runs **locally on the same Ollama runtime** using a separate text/instruct model (parakeet is ASR-only), orchestrated by the pi coding agent; a cloud model is an optional fallback.
- Add **editable prompts**: the generation prompts ship as Markdown and are editable in the app's Markdown editor; edits are persisted and used on the next run.
- Persist generated artifacts to the episode folder (for publish) and to the backend (for shared viewing), each as a resumable/stateful step like the publish pipeline.
- Surface these pre-publish stages (Transcribe → Shownotes → Social → SEO) in the flow visualization ahead of the publish stages.

Out of scope: Zencastr API ingest (audio is assumed present in the episode folder), cloud-only generation as the default (local-first; cloud model optional), and any change to the publish targets.

## Capabilities

### New Capabilities
- `transcription`: produce and persist a text transcript from an episode's audio using a local engine (quicksubs + parakeet via Ollama), as a stateful, re-runnable step.
- `content-generation`: generate shownotes, platform social posts, and SEO/metadata from a transcript using editable, prompt-driven templates run through the pi coding agent, persisting results for publish and shared viewing.

### Modified Capabilities
<!-- None as spec deltas: this change depends on capabilities introduced by add-podflow-desktop-foundation
     (episode-state-backend, episode-storage-config, app-onboarding, desktop-flow-visualization), but those
     are not yet archived into openspec/specs/, so they are referenced as dependencies rather than modified here. -->

## Impact

- **Desktop app**: new transcription + generation controls, a Markdown prompt editor, and new pre-publish stages in the flow view.
- **Backend**: stores transcript + generated content per episode (extends the episode record established by the foundation change).
- **External tools**: depends on onboarding-provisioned Ollama + parakeet model (transcription) and a local instruct model (generation), plus the pi coding agent; invokes quicksubs for transcription.
- **Episode folder**: new generated files (e.g. transcript, `content-*.md`, social, SEO) written alongside existing episode assets.
- **Prompts**: shipped as Markdown assets (`assets/prompts/`), user-editable at runtime.
- **Depends on**: `add-podflow-desktop-foundation` (storage root, backend, onboarding, flow visualization).
