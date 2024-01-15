package targets

import (
	"encoding/base64"
	"encoding/json"
	"fmt"
	"log"
	"os"
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
    Chapters string `json:"chapters,omitempty"`
    InputFile string `json:"input_file,omitempty"`
    Image string `json:"image,omitempty"`
    MetaData Metadata `json:"metadata"`
    Action string `json:"action"`
}

func StartAuphonicProduction(host string, step config.Step) (int, error) {

    auphonicConfig := step.Auphonic
    method := "POST"
	url := host + "/api/productions.json"

    fmt.Printf("\n  Create " + auphonicConfig.Title + " Production\n")

	headers := map[string]string{
		"Content-Type": "application/json",
		"Authorization": fmt.Sprintf("Basic %s", base64.StdEncoding.EncodeToString([]byte(auphonicConfig.Username+":"+auphonicConfig.Password))),
	}

    var successfulProductions = 0
    for _, file := range auphonicConfig.Files {
        if _, err := os.Stat(file.Episode); !os.IsNotExist(err) {
            body := AuphonicRequest{
                Preset: auphonicConfig.Preset,
                MetaData: Metadata{
                    Title: auphonicConfig.Title,
                },
                InputFile: auphonicConfig.FileServer + file.Episode,
                Action: "start",
            }

            if file.Chapters != "" {
                body.Chapters = auphonicConfig.FileServer + file.Chapters
            }

            if file.Image != "" {
                body.Image = auphonicConfig.FileServer + file.Image

            }

            resp, err := SendHTTPRequest(method, url, headers, body)

            if err != nil {
                return successfulProductions, err
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

            successfulProductions++
        }
    }


    return successfulProductions, nil
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
