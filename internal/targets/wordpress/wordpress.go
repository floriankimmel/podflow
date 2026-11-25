package wordpress

import (
	"encoding/json"
	"fmt"
	"os"
	"strings"

	config "github.com/floriankimmel/podflow/internal/configuration"
	"github.com/floriankimmel/podflow/internal/markdown"
)

// Site is the WordPress installation with Podlove and Yoast.
type Site struct {
	Server string
	APIKey string
}

// Post is everything the episode's website post shows.
type Post struct {
	Title         string
	EpisodeNumber string
	// ReleaseDate is the WordPress post date, "yyyy-MM-dd HH:mm:ss".
	ReleaseDate string
	// AudioSlug is the Podlove slug: the audio file's base name on the server.
	AudioSlug string
	// ShowNotesFile is the shownotes markdown; skipped when the file is missing.
	ShowNotesFile string
	// FeaturedImageFile is uploaded once and shown above the post.
	FeaturedImageFile string
	// CoverURL is the public URL of the Cover, used as the Podlove poster.
	CoverURL     string
	ChaptersFile string
	SEO          SEOTexts
}

// SEOTexts are the Yoast and Podlove texts taken from seo.md.
type SEOTexts struct {
	MetaDescription string
	FocusKeywords   string
}

// IDs are what ScheduleEpisode creates. Passing them back in resumes a run
// without creating the post or uploading the featured image again.
type IDs struct {
	PodloveID       json.Number
	WordpressID     string
	FeaturedMediaID string
}

// NewPost builds the post from a CLI wordpress step.
func NewPost(cfg config.Wordpress, title, episodeNumber, releaseDate string) (Post, error) {
	post := Post{
		Title:             title,
		EpisodeNumber:     episodeNumber,
		ReleaseDate:       releaseDate,
		AudioSlug:         cfg.Episode,
		ShowNotesFile:     cfg.ShowNotes,
		FeaturedImageFile: cfg.Image,
		CoverURL:          cfg.Poster,
		ChaptersFile:      cfg.Chapter,
	}
	if cfg.ContentFile != "" {
		path := strings.ReplaceAll(cfg.ContentFile, "{{episodeNumber}}", episodeNumber)
		content, err := os.ReadFile(path)
		if err != nil {
			return Post{}, err
		}
		sections := SEOSections(string(content))
		post.SEO = SEOTexts{
			MetaDescription: sections["Meta-Description"],
			FocusKeywords:   sections["Focus Keywords"],
		}
	}
	return post, nil
}

// ScheduleEpisode creates or updates the episode's website post and schedules
// it for its release date. save is called whenever a new id exists, so a
// failed run can resume from the ids it returns or saved.
func ScheduleEpisode(site Site, post Post, ids IDs, save func(IDs) error) (IDs, error) {
	fmt.Printf(" Schedule blogpost '%s' for %s \n", post.Title, post.ReleaseDate)
	api := client{site: site}

	if ids.WordpressID == "" {
		fmt.Println(" Initiating episode")
		podloveID, wordpressID, err := api.createEpisode()
		if err != nil {
			return ids, err
		}
		ids.PodloveID, ids.WordpressID = podloveID, wordpressID
		if err := save(ids); err != nil {
			return ids, err
		}
	} else {
		fmt.Println(" Episode already initiated")
	}

	podlove := api.podloveEpisode(ids.PodloveID)
	wp := api.wordpressPost(ids.WordpressID)

	content := ""
	if _, err := os.Stat(post.ShowNotesFile); err == nil {
		notes, err := os.ReadFile(post.ShowNotesFile)
		if err != nil {
			return ids, err
		}
		content = markdown.ToHTML(string(notes))
	}

	if ids.FeaturedMediaID == "" {
		fmt.Println(" Uploading featured image")
		mediaID, err := api.uploadImage(post.Title, post.FeaturedImageFile)
		if err != nil {
			return ids, err
		}
		ids.FeaturedMediaID = mediaID
		if err := save(ids); err != nil {
			return ids, err
		}
	} else {
		fmt.Println(" Featured image already uploaded")
	}

	chapters, err := readChapters(post.ChaptersFile)
	if err != nil {
		return ids, err
	}

	steps := []struct {
		name string
		run  func() error
	}{
		{"title", func() error {
			return podlove(map[string]any{"title": fmt.Sprintf("LEP#%s - %s", post.EpisodeNumber, post.Title)})
		}},
		{"URL", func() error { return wp(map[string]any{"slug": post.EpisodeNumber}) }},
		{"slug", func() error { return podlove(map[string]any{"slug": post.AudioSlug}) }},
		{"episode number", func() error { return podlove(map[string]any{"number": withoutLetters(post.EpisodeNumber)}) }},
		{"show notes", func() error {
			if content == "" {
				return nil
			}
			return wp(map[string]any{"content": content})
		}},
		{"release date", func() error { return wp(map[string]any{"status": "future", "date": post.ReleaseDate}) }},
		{"featured image", func() error { return wp(map[string]any{"featured_media": ids.FeaturedMediaID}) }},
		{"poster", func() error { return podlove(map[string]any{"poster": post.CoverURL, "episode_poster": post.CoverURL}) }},
		{"assets", func() error { return api.enableAssets(ids.PodloveID, audioAssetIDs...) }},
		{"chapter markers", func() error { return api.putChapters(ids.PodloveID, chapters) }},
		{"SEO settings", func() error {
			if post.SEO.FocusKeywords == "" && post.SEO.MetaDescription == "" {
				return nil
			}
			return wp(map[string]any{"meta": map[string]string{
				"_yoast_wpseo_focuskw":  post.SEO.FocusKeywords,
				"_yoast_wpseo_metadesc": post.SEO.MetaDescription,
			}})
		}},
		{"summary", func() error {
			if post.SEO.MetaDescription == "" {
				return nil
			}
			return podlove(map[string]any{"summary": post.SEO.MetaDescription})
		}},
	}
	for _, step := range steps {
		fmt.Printf(" Setting %s\n", step.name)
		if err := step.run(); err != nil {
			return ids, fmt.Errorf("wordpress: set %s: %w", step.name, err)
		}
	}
	return ids, nil
}
