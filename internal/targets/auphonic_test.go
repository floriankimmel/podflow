package targets_test

import (
	"encoding/json"
	"io"
	"log"
	"net/http"
	"net/http/httptest"
	config "podflow/internal/configuration"
	"podflow/internal/targets"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)
var testServer *httptest.Server
var _ = BeforeSuite(func() {
    mux := http.NewServeMux()

    mux.HandleFunc("/api/productions.json", func(w http.ResponseWriter, r *http.Request) {
        if r.Method != "POST" {
            log.Println("Method not allowed")
            w.WriteHeader(500)
        }

        if r.Header.Get("Content-type") != "application/json" {
            log.Println("Content type not allowed")
            w.WriteHeader(500)
        }

        body, err := io.ReadAll(r.Body)
        if err != nil {
            w.WriteHeader(500)
            return
        }

        defer r.Body.Close()

        auphonicRequest := targets.AuphonicRequest{}
        if err := json.Unmarshal(body, &auphonicRequest); err != nil {
            w.WriteHeader(500)
            return
        }


        production := targets.Production{
            Result: targets.Result{
                UUID: "21757c63-1d4f-41a8-b385-4a153611f11a",
                Status: "Started",
            },
        }

        response, err := json.Marshal(production)

        if err != nil {
            w.WriteHeader(500)
            return
        }

        if _, err := w.Write(response); err != nil {
            w.WriteHeader(500)
        }
    })
    mux.HandleFunc("/api/production/21757c63-1d4f-41a8-b385-4a153611f11a.json", func(w http.ResponseWriter, r *http.Request) {
        if r.Method != "GET" {
            log.Println("Method not allowed")
            w.WriteHeader(500)
        }

        production := targets.Production{
            Result: targets.Result{
                UUID: "21757c63-1d4f-41a8-b385-4a153611f11a",
                Status: "Done",
            },
        }

        response, err := json.Marshal(production)

        if err != nil {
            w.WriteHeader(500)
            return
        }

        if _, err := w.Write(response); err != nil {
            w.WriteHeader(500)
        }
    })

    testServer = httptest.NewServer(mux)

})

var _ = AfterSuite(func() {
    testServer.Close()
})

var _ = Describe("An auphonic production can be", func() {
    It("started successfully", func() {
        step := config.Step{
            Auphonic: config.Auphonic{
                Username: "username",
                Password: "password",
                Preset: "preset",
                Title: "Done",
                FileServer: "http://localhost:8080/",
                Image: "episode.png",
                Chapters: "episode.chapters.txt",
                Episode: "episode.mp3",
            },
        }


        err := targets.StartAuphonicProduction(testServer.URL, step)

        Expect(err).Should(BeNil())

    })

})