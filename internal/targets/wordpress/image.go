package wordpress

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"mime/multipart"
	"os"
	"podflow/internal/targets"
)

type Image struct {
	ID    json.Number `json:"id"`
	title string
	path  string
}

func (i *Image) uploadTo(server string, apiKey string) error {
	featureMediaBody := &bytes.Buffer{}
	writer := multipart.NewWriter(featureMediaBody)

	file, err := os.Open(i.path)

	if err != nil {
		return err
	}

	if err := writer.WriteField("title", i.title); err != nil {
		return err
	}

	part, err := writer.CreateFormFile("file", i.path)

	if err != nil {
		return err
	}

	if _, err = io.Copy(part, file); err != nil {
		return err
	}

	headers := map[string]string{
		"Authorization":  "Basic " + apiKey,
		"Content-Type":   writer.FormDataContentType(),
		"Content-Length": fmt.Sprintf("%d", featureMediaBody.Len()),
	}

	writer.Close()

	resp, err := targets.SendHTTPRequest(targets.HTTPRequest{
		Method:      "POST",
		URL:         server + "/wp-json/wp/v2/media",
		Headers:     headers,
		Body:        featureMediaBody,
		ProgressBar: true,
	})
	if err != nil {
		return err
	}

	i.ID = toImage(resp.Body).ID
	return nil
}

func toImage(body []byte) Image {
	image := Image{}
	err := json.Unmarshal(body, &image)

	if err != nil {
		log.Println("Error unmarshalling feature media response:", err)
		return Image{}
	}
	return image
}
