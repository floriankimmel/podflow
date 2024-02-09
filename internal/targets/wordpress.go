package targets

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"mime/multipart"
	"os"
	config "podflow/internal/configuration"
	"strings"
	"time"
)

type FeatureMediaResponse struct {
    Id      int  `json:"id"`
}
type PodloveEpisode struct {
    Id      string  `json:"id"`
    PostId  string  `json:"post_id"`
}

type WordpressEpisode struct {
    PostId  string  `json:"post_id"`
}

type BlogPost struct {
    FeatureMediaId  int     `json:"featured_media"`
    Title           string  `json:"title"`
    Status          string  `json:"status"`
    Date            string  `json:"date"`
    Content         string  `json:"content"`
    Slug            string  `json:"slug"`
}

type Chapter struct {
	Start time.Time `json:"start"`
	Title string    `json:"title"`
}

func ScheduleEpisode(
    step config.Step,
    title string,
    currentEpisodeNumber string,
    scheduledDate string,
) (PodloveEpisode, error) {
    fmt.Printf(" Schedule blogpost '%s' for %s \n", title, scheduledDate)
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
    featureMedia , err := uploadFeatureMedia(wordpressConfig, podloveEpisode.Id, title)
    fmt.Println(featureMedia)

    if err != nil {
        return PodloveEpisode{}, err
    }
    fullTitle := fmt.Sprintf("LEP#%s - %s", currentEpisodeNumber, title)

    blogPost := BlogPost{
        FeatureMediaId: featureMedia.Id,
        Title: fullTitle,
        Status: "future",
        Date: scheduledDate,
        Content: "",
        Slug: currentEpisodeNumber,
    }

    fmt.Println(" Updating information on " + podloveEpisode.PostId) 
    err = updateBlogPost(wordpressConfig, podloveEpisode.PostId, blogPost)
    if err != nil {
        return PodloveEpisode{}, err
    }

    fmt.Println(" Setting Assets")
    err = settingAsset(wordpressConfig, podloveEpisode.Id, "2"); if err != nil {
        return PodloveEpisode{}, err
    }
    err = settingAsset(wordpressConfig, podloveEpisode.Id, "3"); if err != nil {
        return PodloveEpisode{}, err
    }

    fmt.Println(" Chapter")
    chapters, err := getChaptersAsJson(wordpressConfig)
    updateErr = updateChapters(wordpressConfig, podloveEpisode.Id, chapters)
    if updateErr != nil {
        return PodloveEpisode{}, err
    }

    return podloveEpisode, nil
}

func getChaptersAsJson(wordpressConfig config.Wordpress) ([]Chapter, error) {
	content, err := os.ReadFile(wordpressConfig.Chapter)
	if err != nil {
        return []Chapter{}, err
	}

	lines := strings.Split(string(content), "\n")
	chapters := []Chapter{}

	for _, line := range lines {
		parts := strings.Split(line, " ")
		if len(parts) < 2 {
			continue
		}

		start, err := time.Parse("15:04:05.000", parts[0])
		if err != nil {
			log.Println("Error parsing timestamp:", err)
			continue
		}

		title := strings.Join(parts[1:], " ")

		chapter := Chapter{
			Start: start,
			Title: title,
		}

		chapters = append(chapters, chapter)
	}

    return chapters, nil
}

func settingAsset(wordpressConfig config.Wordpress, id string, assetId string) error {
    headers := map[string]string{
        "Authorization": "Basic " + wordpressConfig.ApiKey,
    }
    _, err := SendHTTPRequest("POST", wordpressConfig.Server + "/wp-json/podlove/v2/episodes/" + id + "/media/" + assetId + "/enable", headers, nil)

    if err != nil {
        return err
    }
    return nil
}

func updateChapters(wordpressConfig config.Wordpress, id string, chapters []Chapter) error {
    headers := map[string]string{
        "Authorization": "Basic " + wordpressConfig.ApiKey,
        "Content-Type": "application/json",
        "Accept": "application/json",
    }
    _, err := SendHTTPRequest("PUT", wordpressConfig.Server + "/wp-json/podlove/v2/chapters/" + id, headers, chapters)

    if err != nil {
        return err
    }
    return nil
}

func updateBlogPost(wordpressConfig config.Wordpress, id string, blogpost BlogPost) error {
    headers := map[string]string{
        "Authorization": "Basic " + wordpressConfig.ApiKey,
        "Content-Type": "application/json",
    }
    _, err := SendHTTPRequest("POST", wordpressConfig.Server + "/wp-json/wp/v2/episodes/" + id, headers, blogpost)

    if err != nil {
        return err
    }
    return nil
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

    return toWordPressEpisode(response.Body).PostId, nil
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
        log.Println("Error unmarshalling feature media response:", err)
        return FeatureMediaResponse{}
    }
    return featureMedia
}

func toWordPressEpisode(body []byte) WordpressEpisode {
    wordpressEpisode := WordpressEpisode{}
    err := json.Unmarshal(body, &wordpressEpisode)

    if err != nil {
        return WordpressEpisode{}
    }
    return wordpressEpisode
}

func toPodloveEpisode(body []byte) PodloveEpisode {
    podloveEpisode := PodloveEpisode{}
    err := json.Unmarshal(body, &podloveEpisode)

    if err != nil {
        return PodloveEpisode{}
    }
    return podloveEpisode
}
