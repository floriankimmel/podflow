package ai

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"mime/multipart"
	"os"
	"path/filepath"
	config "podflow/internal/configuration"
	"podflow/internal/targets"
	"strings"
	"time"

	"github.com/iFaceless/godub"
)

type TranscribedText struct {
	Text string `yaml:"text"`
}

type TranscribedTextReaderWriter interface {
	Write(config TranscribedText) error
}

type TranscribedTextFile struct{}

func Transcribe(episode string, apiKey string) (TranscribedText, error) {
	transcribe := TranscribedText{}
	for _, chunk := range split(episode) {
		fmt.Printf("Transcribing chunk: %s\n", chunk)
		transcribedChunk, err := transcribeChunk(chunk, apiKey)

		if err != nil {
			return TranscribedText{}, err
		}

		transcribe.Text += transcribedChunk.Text
	}

	return transcribe, nil
}

func transcribeChunk(chunk string, openAiKey string) (TranscribedText, error) {
	transcriptionBody := &bytes.Buffer{}
	writer := multipart.NewWriter(transcriptionBody)

	file, err := os.Open(chunk)

	if err != nil {
		return TranscribedText{}, err
	}

	if err := writer.WriteField("model", "whisper-1"); err != nil {
		return TranscribedText{}, err
	}

	part, err := writer.CreateFormFile("file", chunk)

	if err != nil {
		return TranscribedText{}, err
	}

	if _, err = io.Copy(part, file); err != nil {
		return TranscribedText{}, err
	}

	writer.Close()

	headers := map[string]string{
		"Authorization":       "Bearer " + openAiKey,
		"Content-Type":        writer.FormDataContentType(),
		"OpenAI-Organization": "org-4gX5WL3NrPmrcsmrCi3kOC5b",
	}

	resp, err := targets.SendHTTPRequest(targets.HTTPRequest{
		Method:  "POST",
		URL:     "https://api.openai.com/v1/audio/transcriptions",
		Headers: headers,
		Body:    transcriptionBody,
	})
	if err != nil {
		return TranscribedText{}, err
	}

	return toTranscribedText(resp.Body), nil
}

func split(episode string) []string {
	entireEpisode, _ := godub.NewLoader().Load(episode)
	duration := entireEpisode.Duration()
	tenMin, _ := time.ParseDuration("10m")

	var splits []string

	for start, index := time.Duration(0), 1; start < duration; start, index = start+tenMin, index+1 {
		slicedSegment, _ := entireEpisode.Slice(time.Duration(start.Minutes()), tenMin)
		fmt.Printf("Slicing from %f to %f\n", start.Minutes(), start.Minutes()+tenMin.Minutes())
		outputFileName := strings.Replace(episode, ".m4a", fmt.Sprintf("_part%d.m4a", index), 1)
		splits = append(splits, outputFileName)

		if err := godub.NewExporter(outputFileName).WithDstFormat("m4a").Export(slicedSegment); err != nil {
			return []string{}
		}
	}

	return splits

}

func toTranscribedText(body []byte) TranscribedText {
	response := TranscribedText{}
	err := json.Unmarshal(body, &response)

	if err != nil {
		log.Println("Error unmarshalling open ai response:", err)
		return TranscribedText{}
	}
	return response
}

func (file TranscribedTextFile) Write(transcribed TranscribedText) error {
	transcribedTextFilePath := file.GetTranscribedTextFilePath()

	if err := createTranscribedTextFile(transcribedTextFilePath); err != nil {
		return err
	}

	err := os.WriteFile(transcribedTextFilePath, []byte(transcribed.Text), 0600)

	if err != nil {
		return err
	}

	return nil
}

func createTranscribedTextFile(transcribedTextFilePath string) error {
	if _, err := os.Stat(transcribedTextFilePath); os.IsNotExist(err) {
		file, err := os.Create(transcribedTextFilePath)
		if err != nil {
			return err
		}
		defer file.Close()
	}
	return nil
}

func (file TranscribedTextFile) GetTranscribedTextFilePath() string {
	path := config.Dir()
	return filepath.Join(path, filepath.Base(path)+".transcribed.txt")
}
