package cmd

import (
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"

	config "github.com/floriankimmel/podflow/internal/configuration"
	"github.com/floriankimmel/podflow/internal/state"
)

// EpisodeInput is everything the desktop app hands over to publish an
// episode's website post: `podflow publish-episode <publish.json>`.
// Secrets come from the environment (FTP_USER, FTP_PWD, WP_KEY).
type EpisodeInput struct {
	EpisodeNumber string    `json:"episodeNumber"`
	Title         string    `json:"title"`
	ReleaseDate   time.Time `json:"releaseDate"`
	// AudioSlug is the audio file's base name on the server (Podlove slug).
	AudioSlug string `json:"audioSlug"`
	// CoverFile and FeaturedImageFile are file names in the episode folder.
	CoverFile         string `json:"coverFile"`
	FeaturedImageFile string `json:"featuredImageFile"`
	// CoverBaseURL is the public URL prefix of the FTP upload folder.
	CoverBaseURL    string `json:"coverBaseURL"`
	WordpressServer string `json:"wordpressServer"`
	FTP             struct {
		Host string `json:"host"`
		Port string `json:"port"`
	} `json:"ftp"`
}

// Files the episode folder must contain; written by the desktop app's run.
const (
	showNotesFile = "shownotes.md"
	seoFile       = "seo.md"
	chaptersFile  = "chapters.txt"
)

// ReadEpisodeInput reads and checks a publish.json.
func ReadEpisodeInput(path string) (EpisodeInput, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return EpisodeInput{}, err
	}
	var input EpisodeInput
	if err := json.Unmarshal(data, &input); err != nil {
		return EpisodeInput{}, fmt.Errorf("%s: %w", path, err)
	}
	var missing []string
	for name, value := range map[string]string{
		"episodeNumber": input.EpisodeNumber, "title": input.Title, "audioSlug": input.AudioSlug,
		"coverFile": input.CoverFile, "featuredImageFile": input.FeaturedImageFile,
		"coverBaseURL": input.CoverBaseURL, "wordpressServer": input.WordpressServer, "ftp.host": input.FTP.Host,
	} {
		if value == "" {
			missing = append(missing, name)
		}
	}
	if input.ReleaseDate.IsZero() {
		missing = append(missing, "releaseDate")
	}
	if len(missing) > 0 {
		return EpisodeInput{}, fmt.Errorf("%s: missing %s", path, strings.Join(missing, ", "))
	}
	return input, nil
}

// CoverTarget is the Cover's file name on the server: the audio slug with
// the Cover's extension.
func (in EpisodeInput) CoverTarget() string {
	return in.AudioSlug + filepath.Ext(in.CoverFile)
}

// Configuration is the publish config for this episode: upload the Cover by
// FTP, then schedule the website post.
func (in EpisodeInput) Configuration() config.Configuration {
	port := in.FTP.Port
	if port == "" {
		port = "21"
	}
	return config.Configuration{
		CurrentEpisode: in.EpisodeNumber,
		Files: []config.EpisodeFile{
			{Name: "Shownotes", FileName: showNotesFile, Required: true},
			{Name: "SEO", FileName: seoFile, Required: true},
			{Name: "Cover", FileName: in.CoverFile, Required: true},
			{Name: "Featured image", FileName: in.FeaturedImageFile, Required: true},
		},
		Steps: []config.Step{
			{FTP: config.FTP{
				Host:     in.FTP.Host,
				Port:     port,
				Username: "{{env.FTP_USER}}",
				Password: "{{env.FTP_PWD}}",
				Files:    []config.FtpFile{{Source: in.CoverFile, Target: in.CoverTarget()}},
			}},
			{Wordpress: config.Wordpress{
				APIKey:      "{{env.WP_KEY}}",
				Server:      in.WordpressServer,
				Image:       in.FeaturedImageFile,
				Poster:      strings.TrimSuffix(in.CoverBaseURL, "/") + "/" + in.CoverTarget(),
				Episode:     in.AudioSlug,
				ShowNotes:   showNotesFile,
				Chapter:     chaptersFile,
				ContentFile: seoFile,
			}},
		},
	}
}

// wordpressDateLayout is how WordPress takes a post date: site-local time.
const wordpressDateLayout = "2006-01-02 15:04:05"

// PublishEpisode publishes from an EpisodeInput without prompts or a config
// file. Progress stays in <folder>.state.yml, so a failed run resumes. Step
// status is reported by the caller, not by this command.
func PublishEpisode(input EpisodeInput, stateIo state.StateReaderWriter, workingDir string) error {
	current, err := stateIo.Read()
	if err != nil && !errors.Is(err, os.ErrNotExist) {
		return err
	}
	current.Metadata = state.Metadata{
		EpisodeNumber: input.EpisodeNumber,
		Title:         input.Title,
		ReleaseDate:   input.ReleaseDate.Local().Format(wordpressDateLayout),
	}
	if err := stateIo.Write(current); err != nil {
		return err
	}
	return publish(&config.InMemory{Config: input.Configuration()}, stateIo, nil, workingDir, false)
}
