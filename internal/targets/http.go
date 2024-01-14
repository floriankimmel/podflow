package targets

import (
	"bytes"
	"encoding/json"
	"errors"
	"log"
	"net/http"
)

type APIResponse struct {
	Status int
	Body   []byte
}

func SendHTTPRequest(method, url string, headers map[string]string, body interface{}) (*APIResponse, error) {
	var jsonPayload []byte
	if body != nil {
		var err error
		jsonPayload, err = json.Marshal(body)
		if err != nil {
			return nil, err
		}
	}

    log.Printf("Sending request to %s with payload %s\n", url, string(jsonPayload))
    log.Printf("Headers: %s\n", headers)
    log.Printf("Method: %s\n", method)
	req, err := http.NewRequest(method, url, bytes.NewBuffer(jsonPayload))
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

    if resp.StatusCode != 200 {
        log.Printf("Error sending request: %s\n", resp.Status)
        return nil, errors.New("Error sending request")

    }

	apiResponse := &APIResponse{
		Status: resp.StatusCode,
	}

	buf := new(bytes.Buffer)
    if _, err := buf.ReadFrom(resp.Body); err != nil {
        return nil, err
    }
	apiResponse.Body = buf.Bytes()

	return apiResponse, nil
}
