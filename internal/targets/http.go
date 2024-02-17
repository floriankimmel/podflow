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

type HTTPRequest struct {
	Method  string
	URL     string
	Headers map[string]string
	Body    interface{}
}

func SendHTTPRequest(request HTTPRequest) (*APIResponse, error) {
	var payload io.Reader

	log.Printf("Headers: %s\n", request.Headers)
	log.Printf("Method: %s\n", request.Method)

	if request.Headers["Content-Type"] == "application/json" {
		var jsonPayload []byte
		if request.Body != nil {
			var err error
			jsonPayload, err = json.Marshal(request.Body)
			if err != nil {
				return nil, err
			}
		}

		log.Printf("Sending request to %s with payload %s\n", request.URL, string(jsonPayload))
		payload = bytes.NewBuffer(jsonPayload)
	}

	if strings.Contains(request.Headers["Content-Type"], "multipart/form-data") {
		payload = request.Body.(*bytes.Buffer)
		log.Printf("Sending request to %s with payload %s\n", request.URL, payload)
	}

	req, err := http.NewRequest(request.Method, request.URL, payload)
	if err != nil {
		return nil, err
	}

	for key, value := range request.Headers {
		req.Header.Set(key, value)
	}

	client := &http.Client{}
	resp, err := client.Do(req)

	apiResponse := &APIResponse{
		Status: resp.StatusCode,
	}

	if err != nil {
		log.Printf("Error sending request: %s\n", err)
		return apiResponse, err
	}

	defer resp.Body.Close()

	buf := new(bytes.Buffer)
	if _, err := buf.ReadFrom(resp.Body); err != nil {
		return nil, err
	}

	apiResponse.Body = buf.Bytes()

	if resp.StatusCode != 200 && resp.StatusCode != 201 {
		log.Printf("Error sending request: %s\n", resp.Status)
		log.Printf("Response body: %s\n", apiResponse.Body)
		return apiResponse, errors.New("error sending request")
	}

	log.Printf("Response body: %s\n", string(apiResponse.Body))
	return apiResponse, nil
}
