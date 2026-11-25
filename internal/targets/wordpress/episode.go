package wordpress

import (
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"strings"
	"unicode"

	"github.com/floriankimmel/podflow/internal/targets"
)

const podloveURLPath = "/wp-json/podlove/v2/episodes/"
const podloveChaptersURLPath = "/wp-json/podlove/v2/chapters/"
const wpURLPath = "/wp-json/wp/v2/episodes/"
const mediaURLPath = "/wp-json/wp/v2/media"

// audioAssetIDs are the Podlove episode assets (audio files) to enable.
var audioAssetIDs = []string{"2", "3"}

type chapter struct {
	Start string `json:"start"`
	Title string `json:"title"`
}

type chapters struct {
	Chapters []chapter `json:"chapters"`
}

type client struct {
	site Site
}

func (c client) headers() map[string]string {
	return map[string]string{
		"Authorization": "Basic " + c.site.APIKey,
		"Content-Type":  "application/json",
	}
}

func (c client) send(method, path string, body any) ([]byte, error) {
	resp, err := targets.SendHTTPRequest(targets.HTTPRequest{
		Method:  method,
		URL:     c.site.Server + path,
		Headers: c.headers(),
		Body:    body,
	})
	if err != nil {
		return nil, err
	}
	return resp.Body, nil
}

// podloveEpisode returns a setter for fields of the Podlove episode.
func (c client) podloveEpisode(id json.Number) func(map[string]any) error {
	return func(fields map[string]any) error {
		_, err := c.send("POST", podloveURLPath+string(id), fields)
		return err
	}
}

// wordpressPost returns a setter for fields of the WordPress episode post.
func (c client) wordpressPost(id string) func(map[string]any) error {
	return func(fields map[string]any) error {
		_, err := c.send("POST", wpURLPath+id, fields)
		return err
	}
}

// createEpisode creates a Podlove episode, which creates its WordPress post.
func (c client) createEpisode() (json.Number, string, error) {
	created, err := c.send("POST", podloveURLPath, nil)
	if err != nil {
		return "", "", fmt.Errorf("wordpress: create episode: %w", err)
	}
	var episode struct {
		PodloveID   json.Number `json:"id"`
		WordpressID string      `json:"post_id"`
	}
	if err := json.Unmarshal(created, &episode); err != nil {
		return "", "", fmt.Errorf("wordpress: create episode: %w", err)
	}
	podloveID := episode.PodloveID

	info, err := c.send("GET", podloveURLPath+string(podloveID), nil)
	if err != nil {
		return "", "", fmt.Errorf("wordpress: read episode %s: %w", podloveID, err)
	}
	if err := json.Unmarshal(info, &episode); err != nil {
		return "", "", fmt.Errorf("wordpress: read episode %s: %w", podloveID, err)
	}
	if episode.WordpressID == "" {
		return "", "", fmt.Errorf("wordpress: episode %s has no post id", podloveID)
	}
	return podloveID, episode.WordpressID, nil
}

func (c client) enableAssets(podloveID json.Number, assetIDs ...string) error {
	for _, asset := range assetIDs {
		if _, err := c.send("POST", podloveURLPath+string(podloveID)+"/media/"+asset+"/enable", nil); err != nil {
			return err
		}
	}
	return nil
}

func (c client) putChapters(podloveID json.Number, list chapters) error {
	_, err := c.send("PUT", podloveChaptersURLPath+string(podloveID), list)
	return err
}

func withoutLetters(s string) string {
	var result strings.Builder
	for _, r := range s {
		if !unicode.IsLetter(r) {
			result.WriteRune(r)
		}
	}
	return result.String()
}

// readChapters reads "<start> <title>" lines. A missing file means the
// episode has no chapters.
func readChapters(file string) (chapters, error) {
	content, err := os.ReadFile(file)
	if errors.Is(err, os.ErrNotExist) {
		return chapters{Chapters: []chapter{}}, nil
	}
	if err != nil {
		return chapters{}, fmt.Errorf("wordpress: read chapters: %w", err)
	}
	list := []chapter{}
	for _, line := range strings.Split(string(content), "\n") {
		parts := strings.Split(line, " ")
		if len(parts) < 2 {
			continue
		}
		list = append(list, chapter{Start: parts[0], Title: strings.Join(parts[1:], " ")})
	}
	return chapters{list}, nil
}
