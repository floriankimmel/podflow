package targets

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"mime/multipart"
	"os"
	config "podflow/internal/configuration"
)

type FeatureMediaResponse struct {
    Id      string  `json:"id"`
}
type PodloveEpisode struct {
    Id      string  `json:"id"`
    PostId  string  `json:"post_id"`
}

func ScheduleEpisode(
    step config.Step,
    title string,
    currentEpisodeNumber string,
    scheduledDate string,
) (PodloveEpisode, error) {
    fmt.Printf(" Schedule episode %s for %s \n", title, scheduledDate)
    wordpressConfig := step.Wordpress

    fmt.Println(" Initiating episode")
    podloveEpisode, err := createEpisode(wordpressConfig, title, currentEpisodeNumber)

    if err != nil {
        return PodloveEpisode{}, err
    }

    updateErr := updateEpisode(wordpressConfig, podloveEpisode.Id, title, currentEpisodeNumber)

    if updateErr != nil {
        return PodloveEpisode{}, err
    }

    podloveEpisode.PostId, err = getPostId(wordpressConfig, podloveEpisode.Id)

    if err != nil {
        return PodloveEpisode{}, err
    }

    fmt.Println(" Uploading feature image")
    _ , err = uploadFeatureMedia(wordpressConfig, podloveEpisode.Id, title)

    if err != nil {
        return PodloveEpisode{}, err
    }

    return podloveEpisode, nil
}

func createEpisode(wordpressConfig config.Wordpress, title string, currentEpisodeNumber string) (PodloveEpisode, error) {
    headers := map[string]string{
        "Authorization": "Basic " + wordpressConfig.ApiKey,
    }
    podloveEpisodeResponse, err := SendHTTPRequest("POST", wordpressConfig.Server + "/wp-json/podlove/v2/episodes", headers, nil)

    podloveEpisode := toPodloveEpisode(podloveEpisodeResponse.Body)

    if err != nil {
        return PodloveEpisode{}, err
    }
    return podloveEpisode, nil
}

func updateEpisode(
    wordpressConfig config.Wordpress,
    id string,
    title string,
    currentEpisodeNumber string,
) error {
    headers := map[string]string{
        "Authorization": "Basic " + wordpressConfig.ApiKey,
        "Content-Type": "application/json",
    }
    
    body := map[string]string{
        "slug": wordpressConfig.Episode,
        "title": title,
        "number": currentEpisodeNumber,
    }

    _, err := SendHTTPRequest(
        "POST",
        wordpressConfig.Server + "/wp-json/podlove/v2/episodes/" + id,
        headers,
        body,
    )
    return err

}

func getPostId(wordpressConfig config.Wordpress, id string) (string, error) {
    headers := map[string]string{
        "Authorization": "Basic " + wordpressConfig.ApiKey,
        "Content-Type": "application/json",
    }

    response, err := SendHTTPRequest("GET", wordpressConfig.Server + "/wp-json/podlove/v2/episodes/" + id, headers, nil)
    if err != nil {
        return "", err
    }
    return toPodloveEpisode(response.Body).PostId, nil
}

func uploadFeatureMedia(wordpressConfig config.Wordpress, episodeId string, title string) (FeatureMediaResponse, error) {
    featureMediaBody := &bytes.Buffer{}
	writer := multipart.NewWriter(featureMediaBody)

	file, err := os.Open(wordpressConfig.Image)

	if err != nil {
        return FeatureMediaResponse{}, err
	}

    err = writer.WriteField("title", title); if err != nil {
        return FeatureMediaResponse{}, err
    }

	part, err := writer.CreateFormFile("file", wordpressConfig.Image)

	if err != nil {
        return FeatureMediaResponse{}, err
	}

	_, err = io.Copy(part, file)

	if err != nil {
        return FeatureMediaResponse{}, err
	}

    headers := map[string]string{
        "Authorization": "Basic " + wordpressConfig.ApiKey,
        "Content-Type": writer.FormDataContentType(),
        "Content-Length": fmt.Sprintf("%d", featureMediaBody.Len()),
    }

    writer.Close()

    resp, err := SendHTTPRequest("POST", wordpressConfig.Server + "/wp-json/wp/v2/media", headers, featureMediaBody)
    if err != nil {
        return FeatureMediaResponse{}, err
    }

    return toFeatureMediaResponse(resp.Body), nil
}

func toFeatureMediaResponse(body []byte) FeatureMediaResponse {
    featureMedia := FeatureMediaResponse{}
    err := json.Unmarshal(body, &featureMedia)

    if err != nil {
        return FeatureMediaResponse{}
    }
    return featureMedia
}

func toPodloveEpisode(body []byte) PodloveEpisode {
    podloveEpisode := PodloveEpisode{}
    err := json.Unmarshal(body, &podloveEpisode)

    if err != nil {
        return PodloveEpisode{}
    }
    return podloveEpisode
}
