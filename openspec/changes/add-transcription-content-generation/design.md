# Design

## Context

See proposal.md — Why. This change depends on `add-podflow-desktop-foundation`: storage root (episodes as subfolders), backend as source of truth, onboarding-provisioned tools, and the flow visualization. The generation prompts already exist as Markdown assets at `assets/prompts/` (01-shownotes, 02-social-media, 03-seo) and are moved into this change.

Key facts that shape the approach:
- **Ownership: the macOS app owns transcription and generation** (invoking quicksubs, Ollama, and the pi agent locally, writing episode files, and reporting steps to the backend). The podflow Go CLI is unchanged — it still owns only the `publish` pipeline and its backend state sync.
- `parakeet` is a speech-to-text (ASR) model — it transcribes audio only and cannot generate text.
- Ollama is a general local model runtime: the same install can host both the ASR model and a text/instruct LLM.
- Compute is local-first (user's choice); the pi coding agent runs the prompt skills.

## Goals / Non-Goals

**Goals:**
- Episode audio → transcript → shownotes → social → SEO, local-first, each a stateful re-runnable step.
- Reuse the existing Ollama runtime for both transcription and generation to keep cost ~zero.
- Keep prompts editable at runtime (Markdown editor) and decoupled from code.

**Non-Goals:**
- Zencastr API ingest (audio assumed present in the episode folder).
- Cloud generation as the default (supported as an optional fallback only).
- Changing publish targets or the publish state machine.

## Decisions

### D1: Transcription — quicksubs + parakeet via Ollama, local only
Run quicksubs against the episode's primary audio using the parakeet model served by Ollama; write the transcript into the episode folder and record the step in the backend. No audio leaves the machine. Alternative (cloud ASR) rejected: cost and privacy.

### D2: Content generation runs locally on an Ollama text LLM (reuse the runtime)
Generation uses the **same Ollama install** as transcription, but with a **separate text/instruct model** (parakeet cannot generate text). **Default model (resolved): `qwen2.5:14b-instruct`** on 32GB+ Apple Silicon, falling back to **`qwen2.5:7b-instruct`** on 16GB machines. Rationale: Qwen2.5 has the strongest German quality + instruction-following in the local 7–14B class (critical for the strict "output only", length, and format constraints in the prompts) and a large context window (handles long transcripts with little/no chunking). `gemma2:9b` is the German-leaning alternative; `llama3.1:8b` is weaker on German. Near-zero marginal cost, offline, privacy; one runtime to manage. Trade-off: local quality < frontier cloud → mitigated by D3.

### D3: pi agent orchestrates prompts; model target is configurable (local default, cloud optional)
The pi coding agent fills prompt placeholders and runs each prompt. The model is configurable per install: **local Ollama model by default**, with an optional cloud model (e.g. for a higher-quality pass or when the local result is poor). Rationale: cheap by default, escape hatch for quality without re-architecting. Alternative (hardcode cloud) rejected: cost; (hardcode local) rejected: no quality ceiling escape.

### D4: Prompts as editable Markdown assets with placeholder substitution
Ship `assets/prompts/*.md` with placeholders (`{{episode_number}}`, `{{transcript}}`, `{{shownotes}}`, `{{text}}`). The app exposes them in a Markdown editor; edits persist (per install) and are used on the next run. The runtime substitutes placeholders before invoking the model. Rationale: non-technical users tune output without touching code; prompts version with the project.

### D5: Generation chain + persistence
Order: transcript → shownotes → social (from shownotes) → SEO (from shownotes/text). Each step is stateful (skip when done, explicit re-run), writes a file into the episode folder for publish, and records status + content in the backend for shared viewing. Pre-publish stages (Transcribe, Shownotes, Social, SEO) appear in the flow visualization ahead of the publish stages.

**podflow-readable outputs (resolved):** podflow consumes two files from the episode folder — `wordpress.showNotes`/`steadyhq.showNotes` (a Markdown file → `markdown.ToHTML` → episode content) and `wordpress.contentFile` (parsed via regex for `**Meta-Description:**` and `**Focus Keywords:**`, path supports `{{episodeNumber}}`). So shownotes generation writes the shownotes Markdown at podflow's configured shownotes path, and SEO generation writes the content file in exactly that `**Meta-Description:**` / `**Focus Keywords:**` format (which the SEO prompt already emits). Matches the observed episode layout (`<slug>.md`, `content-<slug>.md`). Social posts are stored per platform for the app (not consumed by podflow publish).

### D6: New dependency — a local generation model in onboarding
Generation needs a local instruct model present. Onboarding (from the foundation change) pulls the pinned default (`qwen2.5:14b-instruct`, or `qwen2.5:7b-instruct` on 16GB) via Ollama alongside parakeet; if absent at generation time, the app reports the missing model and points to onboarding (mirrors transcription's engine check). Rationale: keep the one guided setup; fail loud, not silent.

### D7: Long transcripts — rely on context, summarize only as fallback
Send the full transcript to the model and rely on Qwen2.5's large context window (handles typical episode transcripts whole). If a transcript exceeds the model's window, the generator first produces a condensed summary of the transcript and prompts from that, rather than silently truncating. Rationale: one simple path for the common case, a deterministic fallback for the rare long one; no change to observable outputs.

## Risks / Trade-offs

- [Local LLM quality for German shownotes/SEO] → configurable cloud fallback (D3); prompts tuned for the chosen model; user can regenerate.
- [Model/runtime drift (Ollama or model updates change output)] → pin the default model tag; prompts editable to adapt.
- [Large model downloads] → provisioned via onboarding as resumable pulls; generation blocks only on its own model, not parakeet.
- [parakeet mistaken for a generation model] → explicit two-model split (ASR vs instruct) documented here and enforced by the engine/model checks.
- [Long transcripts exceed local context window] → chunk or summarize before prompting; keep prompts transcript-delimited; implementation detail resolved per model.

## Migration Plan

1. Land after the foundation change; onboarding gains the generation model pull.
2. Ship transcription first (independently useful), then generation steps.
3. Rollback: disable generation/transcription steps; publish and visualization continue unaffected.

## Open Questions

None.
