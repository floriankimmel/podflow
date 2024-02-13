package targets

import (
	"bytes"
	"encoding/json"
	"errors"
	"io"
	"log"
	"net/http"
	"strings"
)

type APIResponse struct {
	Status int
	Body   []byte
}

func SendHTTPRequest(method, url string, headers map[string]string, body interface{}) (*APIResponse, error) {
	var payload io.Reader

	log.Printf("Headers: %s\n", headers)
	log.Printf("Method: %s\n", method)

	if headers["Content-Type"] == "application/json" {
		var jsonPayload []byte
		if body != nil {
			var err error
			jsonPayload, err = json.Marshal(body)
			if err != nil {
				return nil, err
			}
		}

		log.Printf("Sending request to %s with payload %s\n", url, string(jsonPayload))
		payload = bytes.NewBuffer(jsonPayload)
	}

	if strings.Contains(headers["Content-Type"], "multipart/form-data") {
		payload = body.(*bytes.Buffer)
		log.Printf("Sending request to %s with payload %s\n", url, payload)
	}

	req, err := http.NewRequest(method, url, payload)
	if err != nil {
		return nil, err
	}

	for key, value := range headers {
		req.Header.Set(key, value)
	}

	client := &http.Client{}
	resp, err := client.Do(req)

	if err != nil {
		return nil, err
	}

	defer resp.Body.Close()

	apiResponse := &APIResponse{
		Status: resp.StatusCode,
	}

	buf := new(bytes.Buffer)
	if _, err := buf.ReadFrom(resp.Body); err != nil {
		return nil, err
	}

	apiResponse.Body = buf.Bytes()
	if resp.StatusCode != 200 && resp.StatusCode != 201 {
		log.Printf("Error sending request: %s\n", resp.Status)
		log.Printf("Response body: %s\n", apiResponse.Body)
		return nil, errors.New("error sending request")
	}

	log.Printf("Response body: %s\n", string(apiResponse.Body))
	return apiResponse, nil
}
