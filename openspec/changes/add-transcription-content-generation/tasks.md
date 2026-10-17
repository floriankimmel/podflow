# Tasks

## 1. Transcription (local, quicksubs + parakeet via Ollama)

- [ ] 1.1 Add an engine/model availability check (Ollama reachable + parakeet present) that points to onboarding when missing; verify a test reports missing vs available states.
- [ ] 1.2 Implement audio discovery in the episode folder (pick primary audio, supported formats); verify a test selects the expected file and errors clearly when none exists.
- [ ] 1.3 Invoke quicksubs with the parakeet model and write the transcript into the episode folder; verify an integration test produces a transcript file for a sample audio with a stubbed/local engine.
- [ ] 1.4 Record the transcription step in the backend and make it stateful (skip when done, forced re-run overwrites); verify tests cover skip, forced re-run, and backend step status = done.

## 2. Generation runtime (local Ollama LLM + pi agent)

- [ ] 2.1 Add a generation-model availability check (local instruct model present in Ollama) with onboarding guidance; verify missing-model path reports and does not generate.
- [ ] 2.2 Implement prompt loading from `assets/prompts/` and placeholder substitution (`{{episode_number}}`, `{{transcript}}`, `{{shownotes}}`, `{{text}}`); verify a unit test substitutes all placeholders correctly.
- [ ] 2.3 Implement a model-target abstraction (local Ollama default, optional cloud fallback) invoked via the pi agent; verify a test runs a prompt against a stubbed local model and honors the configured target.

## 3. Content generation steps

- [ ] 3.1 Implement shownotes generation (type detection interview/host, Markdown-only output) persisting to episode folder + backend; verify a test produces Markdown and records the step, and errors when no transcript exists.
- [ ] 3.2 Implement social post generation for all six platforms (Discord, LinkedIn, Instagram, Strava, Facebook, YouTube) from shownotes; verify a test produces one post per platform from sample shownotes.
- [ ] 3.3 Implement SEO/metadata generation (website, Facebook OG, YouTube title/description/tags) from shownotes/text; verify a test produces all three metadata groups.
- [ ] 3.5 Write shownotes + SEO content in podflow-readable form: shownotes as Markdown at podflow's configured shownotes path; SEO as the content file with `**Meta-Description:**` and `**Focus Keywords:**` lines (honoring `{{episodeNumber}}`); verify podflow's parser reads both from a generated episode folder.
- [ ] 3.4 Make each generation step stateful and independently re-runnable (regenerate one without re-running others); verify tests cover skip-when-done and single-step regeneration.

## 4. Prompt editor

- [ ] 4.1 Add a Markdown prompt editor in the app for the three prompts with persisted edits; verify an edited+saved prompt survives relaunch and is loaded by the runtime.
- [ ] 4.2 Verify edited prompts take effect: a test changes a prompt and confirms the next generation run uses the edited text.
- [ ] 4.3 Allow editing generated artifacts (shownotes, posts) in the Markdown editor with persisted edits used for publish/dependent steps and not overwritten unless regenerated; verify an edited shownotes file is retained and used by publish.

## 5. Flow visualization integration

- [ ] 5.1 Add the pre-publish stages (Transcribe → Shownotes → Social → SEO) ahead of the publish stages in the flow view with the same status styling; verify the stages render with correct statuses from backend state.

## 6. Onboarding dependency (cross-change)

- [ ] 6.1 Extend onboarding to pull the local generation instruct model via Ollama (pinned default `qwen2.5:14b-instruct`, `qwen2.5:7b-instruct` on 16GB) as a resumable step; verify detection + progress for the generation model, independent of parakeet.

## 7. End-to-end integration

- [ ] 7.1 Verify the full local pipeline on a sample episode: audio → transcript → shownotes → social (6 platforms) → SEO, all local via Ollama, with files written to the episode folder and steps recorded in the backend.
- [ ] 7.2 Verify shared viewing: generated content and step statuses are visible to a second client via the backend.

## Workflow follow-up

- Archive the change after the project's review requirements are satisfied.
- Verify the archived result.
