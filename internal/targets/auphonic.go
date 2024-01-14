package targets

import (
	"encoding/base64"
	"encoding/json"
	"fmt"
    "log"
	config "podflow/internal/configuration"
	"strings"
	"time"
)
type Result struct {
    Status string `json:"status_string"`
    UUID string `json:"uuid"`
}

type Production struct {
    Result Result `json:"data"`
}
type Metadata struct {
    Title string `json:"title"`
}

type AuphonicRequest struct {
    Preset string `json:"preset"`
    Chapters string `json:"chapters"`
    InputFile string `json:"input_file"`
    Image string `json:"image"`
    MetaData Metadata `json:"metadata"`
    Action string `json:"action"`
}

func StartAuphonicProduction(host string, step config.Step) error {

    auphonicConfig := step.Auphonic
    method := "POST"
	url := host + "/api/productions.json"

    fmt.Printf("\n  Create " + auphonicConfig.Title + " Production\n")

	headers := map[string]string{
		"Content-Type": "application/json",
		"Authorization": fmt.Sprintf("Basic %s", base64.StdEncoding.EncodeToString([]byte(auphonicConfig.Username+":"+auphonicConfig.Password))),
	}

    body := AuphonicRequest{
        Preset: auphonicConfig.Preset,
        MetaData: Metadata{
            Title: auphonicConfig.Title,
        },
        Chapters: "http://rssfeed.laufendentdecken-podcast.at/data/" + step.Files[2].Source,
        InputFile: "http://rssfeed.laufendentdecken-podcast.at/data/" + step.Files[0].Source,
        Image: "http://rssfeed.laufendentdecken-podcast.at/data/" + step.Files[1].Source,
        Action: "start",
    }

    resp, err := SendHTTPRequest(method, url, headers, body)

	if err != nil {
		return err
	}

    log.Printf("Antwort-Status: %d",resp.Status)
    log.Printf("Antwort-Body: %s", string(resp.Body))
    production := toProductionJson(resp.Body)
    log.Printf("Production-UUID: %s", production.Result.UUID)
    log.Printf("Production-Status: %s", production.Result.Status)

    for production.Result.Status != "Done" {
        output := fmt.Sprintf("\rAuphonic status: %s", production.Result.Status)
		fmt.Print(strings.Repeat(" ", len(output))) 
		fmt.Print(output)

        production.Result.Status = getCurrentStatus(host, auphonicConfig.Username, auphonicConfig.Password, production.Result.UUID)
        time.Sleep(2 * time.Second)
    }


    return nil
}

func getCurrentStatus(host string, username string, password string, uuid string) string {
    method := "GET"
	url := host + "/api/production/"+ uuid +".json"

	headers := map[string]string{
		"Authorization": fmt.Sprintf("Basic %s", base64.StdEncoding.EncodeToString([]byte(username+":"+password))),
	}

    resp, err := SendHTTPRequest(method, url, headers, nil)
	if err != nil && resp.Status != 200 {
		return "Error"
    }	

    return toProductionJson(resp.Body).Result.Status
}

func toProductionJson(body []byte) Production {
    production := Production{}
    err := json.Unmarshal(body, &production)
    if err != nil {
        return Production{}
    }
    return production
}
