package targets

import (
	"os"
	config "podflow/internal/configuration"
	"podflow/internal/markdown"
	"strings"
)

func ScheduleSteadyHq(
	steadyHqConfig config.SteadyHq,
	scheduledDate string,
) (error) {
	content, showNotesErr := os.ReadFile(steadyHqConfig.ShowNotes)

	if showNotesErr != nil {
		return showNotesErr
	}

	body := map[string]string{
		"content": markdown.ToHTML(string(content)),
		"title":   steadyHqConfig.Title,
		"audio_url": steadyHqConfig.Episode,
		"publish_at": strings.ReplaceAll(scheduledDate, " ", "T") + "Z",
		"teaser_image": steadyHqConfig.Image,
		"distribute_as_email": "false",
	}

	_, err := SendHTTPRequest(HTTPRequest{
		Method:      "POST",
		URL:         "https://steadyhq.com/api/v1/posts/audio_posts",
		Headers:     headers(steadyHqConfig.APIKey),
		Body:        body,
		ProgressBar: false,
	})

	return err
}

func headers(apiKey string) map[string]string {
	return map[string]string{
		"X-Api-Key": apiKey,
		"Content-Type":  "application/vnd.api+json; charset=utf-8",
		"Accept": "application/vnd.api+json",
		"Host": "steadyhq.com",
	}
}

