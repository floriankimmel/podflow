import Foundation

// Every name the app shares with the bundled plugin (`plugin/skills/episode/`)
// and the podflow CLI. Swift is the source; `PluginContractTests` checks the
// shipped SKILL.md, prompts and scripts against it.

/// Step ids the plugin writes to `state.json` and reports to the backend.
/// `SKILL.md` has one `### \`<id>\`` heading per step, in `PipelineStage.all` order.
enum StepID {
    static let auphonicCreate = "auphonic_create"
    static let auphonicUpload = "auphonic_upload"
    static let auphonicStart = "auphonic_start"
    static let auphonicWait = "auphonic_wait"
    static let transcript = "transcript"
    static let generateShownotes = "generate_shownotes"
    static let generateSEO = "generate_seo"
    static let generateSocial = "generate_social"
    static let factcheck = "factcheck"
    static let review = "review"
    static let auphonicMetadata = "auphonic_metadata"
    static let auphonicCover = "auphonic_cover"
    static let auphonicPublish = "auphonic_publish"
    static let shownotesYoutubeLink = "shownotes_youtube_link"
    static let wordpress = "wordpress"
    static let scheduled = "scheduled"

    /// Key under which `auphonic_publish` stores the YouTube URL.
    static let youtubeURLKey = "youtubeUrl"
}

/// Files in an episode folder.
enum EpisodeFile {
    static let state = "state.json"
    static let transcript = "transcript.txt"
    static let shownotes = "shownotes.md"
    static let social = "social.md"
    static let seo = "seo.md"
    static let factcheck = "factcheck.md"
    /// Review decisions that live nowhere else (release date).
    static let review = "review.json"
    static let chapters = "chapters.txt"
    static let runLog = "run.log"
    /// Picked images: `<base>.<ext>`. The publish run looks for `cover.*`.
    static let coverBase = "cover"
    static let featuredBase = "wordpress"

    /// Files the plugin reads or writes by name.
    static let plugin = [state, transcript, shownotes, social, seo, factcheck]
}

/// Section labels of `seo.md` ("**<Label>:**"), as the SEO prompt's output
/// format defines them.
enum SEOLabel {
    static let titleTag = "Title Tag"
    static let metaDescription = "Meta-Description"
    static let focusKeywords = "Focus Keywords"
    static let ogTitle = "Facebook OG Title"
    static let ogDescription = "Facebook OG Description"
    static let youtubeTitle = "YouTube Titel"
    static let youtubeDescription = "YouTube Beschreibung"
    static let youtubeTags = "YouTube Tags"

    static let all = [titleTag, metaDescription, focusKeywords, ogTitle, ogDescription,
                      youtubeTitle, youtubeDescription, youtubeTags]
    /// Nothing sets these; they are pasted into WordPress by hand in the review.
    static let manual = [titleTag, ogTitle, ogDescription]
    /// Read by the skill through `seo.sh` (checks and YouTube metadata).
    static let skill = [youtubeTitle, youtubeDescription, youtubeTags, metaDescription]
    /// Read by the podflow CLI for Yoast (`internal/targets/wordpress`).
    static let cli = [metaDescription, focusKeywords]
}

/// Environment variables of a run besides the secrets (`SettingsStore.Secret`,
/// whose raw values are the variable names).
enum EnvName {
    static let auphonicPreset = "AUPHONIC_PRESET"
    static let backendURL = "PODFLOW_BACKEND_URL"
    /// Path of the bundled podflow CLI, used by the skill's `wordpress` step.
    static let cli = "PODFLOW_CLI"
    /// Read by the podflow CLI, not the plugin.
    static let configFile = "PODFLOW_CONFIG_FILE"
}

/// Backend episode profiles. `state.sh` reports steps with the same value.
enum BackendProfile {
    static let video = "video"
}
