package wordpress

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"mime/multipart"
	"os"

	"github.com/floriankimmel/podflow/internal/targets"
)

// uploadImage uploads the featured image and returns its media id.
func (c client) uploadImage(title, path string) (string, error) {
	body := &bytes.Buffer{}
	writer := multipart.NewWriter(body)

	file, err := os.Open(path)
	if err != nil {
		return "", fmt.Errorf("wordpress: featured image: %w", err)
	}
	defer file.Close()

	if err := writer.WriteField("title", title); err != nil {
		return "", err
	}
	part, err := writer.CreateFormFile("file", path)
	if err != nil {
		return "", err
	}
	if _, err = io.Copy(part, file); err != nil {
		return "", err
	}
	if err := writer.Close(); err != nil {
		return "", err
	}

	resp, err := targets.SendHTTPRequest(targets.HTTPRequest{
		Method: "POST",
		URL:    c.site.Server + mediaURLPath,
		Headers: map[string]string{
			"Authorization":  "Basic " + c.site.APIKey,
			"Content-Type":   writer.FormDataContentType(),
			"Content-Length": fmt.Sprintf("%d", body.Len()),
		},
		Body:        body,
		ProgressBar: true,
	})
	if err != nil {
		return "", fmt.Errorf("wordpress: upload featured image: %w", err)
	}

	var media struct {
		ID json.Number `json:"id"`
	}
	if err := json.Unmarshal(resp.Body, &media); err != nil || media.ID == "" {
		return "", fmt.Errorf("wordpress: upload featured image: no media id in response")
	}
	return media.ID.String(), nil
}
