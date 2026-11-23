# Podflow Desktop

Native SwiftUI macOS app for the Laufend-Entdecken podcast. It supports one
flow: finished video → Auphonic → transcript → shownotes, social posts and SEO
→ fact-check → review → YouTube and WordPress.

The app is the UI. The work is done by Claude Code, which the app runs headless
with the bundled `podflow` plugin (`plugin/`). Deterministic API calls live in
the plugin's shell scripts; WordPress publishing is done by the bundled
`podflow` CLI.

## Build

Requires full Xcode and Go:

```sh
cd desktop
make app      # build/Podflow.app incl. plugin, CLI and Sparkle
make run      # build + open
make install  # build + copy to /Applications
make test     # plugin script tests + Swift tests
```

`make` uses Xcode at `/Applications/Xcode.app`; override with `make XCODE=…`.
It signs with the "Developer ID Application" certificate when present.

## Release and updates

Installed apps update themselves with [Sparkle](https://sparkle-project.org).
They check the feed in `SUFeedURL` (Info.plist): `appcast.xml` on the GitHub
release `desktop-appcast`. Each version is its own release `desktop-v<version>`
with the notarized dmg. Neither is marked "latest"; that stays the CLI.

To ship a version:

1. Bump `CFBundleShortVersionString` and `CFBundleVersion` in `Info.plist`.
2. Commit and push.
3. `make publish NOTES="What changed"`: builds, notarizes, creates the
   release and replaces the feed.

Needs the notarytool profile `podflow` and the Sparkle signing key in the
login Keychain (created with Sparkle's `generate_keys`; the public half is
`SUPublicEDKey`). Back the key up with
`.build/artifacts/sparkle/Sparkle/bin/generate_keys -x <file>`. Without it,
installed apps accept no further updates.

## First run

The setup screen opens automatically and

1. installs Claude Code with the official installer if it is missing,
2. signs in to Claude in the browser (each person uses their own account),
3. asks for the shared accounts: Auphonic (user, password, preset id),
   WordPress key, FTP access to the podcast server, workspace key.

Secrets are stored in the Keychain and reach a run only as environment
variables.

### Auphonic preset

The preset must contain

- the outgoing services (YouTube and the podcast server), and
- for interview episodes: speech recognition (Auphonic Whisper, German) with a
  transcript output file in `txt` format.

Productions are created with `review_before_publishing`, so nothing reaches
YouTube or the server before the review in the app.

## Episode flow

Episodes live in `~/Podflow/<number>/` (folder can be changed in the settings, ⌘,).

1. **New episode**: number, title, type, finished video. A Zencastr recording
   also needs the Zencastr transcript file; for an episode with cut-in
   interviews Auphonic produces the transcript.
2. **Prepare** (`/podflow:episode prepare`): Auphonic production and upload,
   transcript, shownotes → social posts, SEO, fact-check.
3. **Review** in the app: edit shownotes and social posts, copy SEO parts that
   are entered by hand (title tag, Facebook texts), read the fact-check, pick
   podcast cover, featured image and release date.
4. **Publish** (`/podflow:episode publish`): YouTube title, description and
   tags go to Auphonic, the production is released, the YouTube link is added
   to the shownotes, and `podflow publish` uploads the cover and schedules the
   WordPress post (including Yoast focus keyword and meta description).

Every step records its status in `state.json`. A failed or interrupted run
resumes at the first unfinished step; the video is not uploaded twice. Step
status is also sent to the shared backend so both hosts see progress.

## Layout

```
plugin/                      Claude Code plugin shipped inside the app
  skills/episode/SKILL.md    orchestration (prepare | publish)
  skills/episode/prompts/    shownotes, social, SEO prompts
  skills/episode/scripts/    auphonic.sh, state.sh, seo.sh (bash, curl, jq)
Sources/Podflow/             app (models, services, views)
Tests/PodflowTests/          Swift tests
Tests/plugin/                script tests against a stub Auphonic server
```

Run the plugin without the app, in an episode folder:

```sh
claude -p "/podflow:episode prepare" --plugin-dir /path/to/desktop/plugin \
  --output-format stream-json --verbose --dangerously-skip-permissions
```

Runs use `--dangerously-skip-permissions`: Claude can run any command without
asking. The app always starts it in the episode folder.
