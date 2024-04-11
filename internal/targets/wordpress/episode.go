package wordpress

import (
	"encoding/json"
	"os"
	"podflow/internal/markdown"
	"podflow/internal/targets"
	"strings"
	"unicode"
)

const podloveURLPath = "/wp-json/podlove/v2/episodes/"
const podloveChaptersURLPath = "/wp-json/podlove/v2/chapters/"
const wpURLPath = "/wp-json/wp/v2/episodes/"

type Episode struct {
	PodloveID   json.Number `json:"id,omitempty"`
	WordpressID string      `json:"post_id,omitempty"`
	Server      string
	APIKey      string
}

type Chapter struct {
	Start string `json:"start"`
	Title string `json:"title"`
}

type Chapters struct {
	Chapters []Chapter `json:"chapters"`
}

func headers(apiKey string) map[string]string {
	return map[string]string{
		"Authorization": "Basic " + apiKey,
		"Content-Type":  "application/json",
	}
}

func (e *Episode) setURL(url string) error {
	body := map[string]string{
		"slug": url,
	}

	_, err := targets.SendHTTPRequest(targets.HTTPRequest{
		Method:      "POST",
		URL:         e.Server + wpURLPath + e.WordpressID,
		Headers:     headers(e.APIKey),
		Body:        body,
		ProgressBar: false,
	})

	return err
}

func (e *Episode) setSlug(slug string) error {
	body := map[string]string{
		"slug": slug,
	}

	_, err := targets.SendHTTPRequest(targets.HTTPRequest{
		Method:      "POST",
		URL:         e.Server + podloveURLPath + string(e.PodloveID),
		Headers:     headers(e.APIKey),
		Body:        body,
		ProgressBar: false,
	})

	return err
}

func (e *Episode) setContent(showNotesFile string) error {
	content, showNotesErr := os.ReadFile(showNotesFile)

	if showNotesErr != nil {
		return showNotesErr
	}

	body := map[string]string{
		"content": markdown.ToHTML(string(content)),
	}

	_, err := targets.SendHTTPRequest(targets.HTTPRequest{
		Method:      "POST",
		URL:         e.Server + wpURLPath + e.WordpressID,
		Headers:     headers(e.APIKey),
		Body:        body,
		ProgressBar: false,
	})

	return err
}

func removeLetters(s string) string {
	var result strings.Builder
	for _, r := range s {
		if !unicode.IsLetter(r) {
			result.WriteRune(r)
		}
	}
	return result.String()
}

func (e *Episode) setEpisodeNumber(episodeNumber string) error {
	body := map[string]string{
		"number": removeLetters(episodeNumber),
	}

	_, err := targets.SendHTTPRequest(targets.HTTPRequest{
		Method:      "POST",
		URL:         e.Server + podloveURLPath + string(e.PodloveID),
		Headers:     headers(e.APIKey),
		Body:        body,
		ProgressBar: false,
	})

	return err
}

func (e *Episode) schedulePostFor(scheduledDate string) error {
	body := map[string]string{
		"status": "future",
		"date":   scheduledDate,
	}

	_, err := targets.SendHTTPRequest(targets.HTTPRequest{
		Method:      "POST",
		URL:         e.Server + wpURLPath + e.WordpressID,
		Headers:     headers(e.APIKey),
		Body:        body,
		ProgressBar: false,
	})

	return err
}

func (e *Episode) setFeaturedMedia(image Image) error {
	body := map[string]string{
		"featured_media": string(image.ID),
	}

	_, err := targets.SendHTTPRequest(targets.HTTPRequest{
		Method:      "POST",
		URL:         e.Server + wpURLPath + e.WordpressID,
		Headers:     headers(e.APIKey),
		Body:        body,
		ProgressBar: false,
	})

	return err
}

func (e *Episode) setTitle(title string) error {
	body := map[string]string{
		"title": title,
	}

	_, err := targets.SendHTTPRequest(targets.HTTPRequest{
		Method:      "POST",
		URL:         e.Server + podloveURLPath + string(e.PodloveID),
		Headers:     headers(e.APIKey),
		Body:        body,
		ProgressBar: false,
	})

	return err
}

func (e *Episode) create(server string, apiKey string) {
	createPodloveEpisodeResponse, podloveErr := targets.SendHTTPRequest(targets.HTTPRequest{
		Method:      "POST",
		URL:         server + podloveURLPath,
		Headers:     headers(apiKey),
		Body:        nil,
		ProgressBar: false,
	})

	if podloveErr != nil {
		panic(podloveErr)
	}

	create, marshalError := toEpisode(createPodloveEpisodeResponse.Body)
	if marshalError != nil {
		panic(marshalError)
	}

	e.PodloveID = create.PodloveID

	getPodloveInfoResponse, podloveInfoErr := targets.SendHTTPRequest(targets.HTTPRequest{
		Method:      "GET",
		URL:         server + podloveURLPath + string(e.PodloveID),
		Headers:     headers(apiKey),
		Body:        nil,
		ProgressBar: false,
	})

	if podloveInfoErr != nil {
		panic(podloveInfoErr)
	}

	info, marshalError := toEpisode(getPodloveInfoResponse.Body)
	if marshalError != nil {
		panic(marshalError)
	}

	e.WordpressID = info.WordpressID
	e.APIKey = apiKey
	e.Server = server
}

func (e *Episode) enableAsset(assetID string) error {
	_, err := targets.SendHTTPRequest(targets.HTTPRequest{
		Method:      "POST",
		URL:         e.Server + podloveURLPath + string(e.PodloveID) + "/media/" + assetID + "/enable",
		Headers:     headers(e.APIKey),
		Body:        nil,
		ProgressBar: false,
	})

	if err != nil {
		return err
	}
	return nil
}

func (e *Episode) addChapters(chapterFile string) error {
	chapters, chaptersErr := chaptersExportToJSON(chapterFile)

	if chaptersErr != nil {
		panic(chaptersErr)
	}

	_, err := targets.SendHTTPRequest(targets.HTTPRequest{
		Method:      "PUT",
		URL:         e.Server + podloveChaptersURLPath + string(e.PodloveID),
		Headers:     headers(e.APIKey),
		Body:        chapters,
		ProgressBar: false,
	})
	if err != nil {
		return err
	}
	return nil
}

func chaptersExportToJSON(chapterFile string) (Chapters, error) {
	content, err := os.ReadFile(chapterFile)
	if err != nil {
		return Chapters{}, err
	}

	lines := strings.Split(string(content), "\n")
	chapters := []Chapter{}

	for _, line := range lines {
		parts := strings.Split(line, " ")

		if len(parts) < 2 {
			continue
		}

		chapter := Chapter{
			Start: parts[0],
			Title: strings.Join(parts[1:], " "),
		}

		chapters = append(chapters, chapter)
	}

	return Chapters{chapters}, nil
}

func toEpisode(body []byte) (Episode, error) {
	episode := Episode{}
	err := json.Unmarshal(body, &episode)

	if err != nil {
		return Episode{}, err
	}

	return episode, nil
}
