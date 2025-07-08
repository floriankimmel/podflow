
package targets_test

import (
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"os"
	config "podflow/internal/configuration"
	"podflow/internal/targets"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("A steadyHQ episode can be", Ordered, func() {
	var steadyHqTestServer *httptest.Server
	var tempFile *os.File

	BeforeAll(func() {
		mux := http.NewServeMux()

		mux.HandleFunc("/api/v1/posts/audio_posts", func(w http.ResponseWriter, r *http.Request) {
			if r.Method != "POST" {
				w.WriteHeader(http.StatusMethodNotAllowed)
				return
			}

			if r.Header.Get("Content-Type") != "application/vnd.api+json; charset=utf-8" {
				w.WriteHeader(http.StatusBadRequest)
				return
			}

			if r.Header.Get("X-Api-Key") != "steady-api-key" {
				w.WriteHeader(http.StatusUnauthorized)
				return
			}

			body, err := io.ReadAll(r.Body)
			if err != nil {
				w.WriteHeader(http.StatusInternalServerError)
				return
			}
			defer r.Body.Close()

			var requestBody map[string]string
			if err := json.Unmarshal(body, &requestBody); err != nil {
				w.WriteHeader(http.StatusBadRequest)
				return
			}

			expectedTitle := "Test Title"
			if requestBody["title"] != expectedTitle {
				w.WriteHeader(http.StatusBadRequest)
				return
			}

			w.WriteHeader(http.StatusCreated)
		})
		steadyHqTestServer = httptest.NewServer(mux)

		var err error
		tempFile, err = os.CreateTemp("", "shownotes.md")
		if err != nil {
			panic(err)
		}
		_, err = tempFile.WriteString("# Show Notes")
		if err != nil {
			panic(err)
		}
		tempFile.Close()
	})

	AfterAll(func() {
		steadyHqTestServer.Close()
		os.Remove(tempFile.Name())
	})

	It("scheduled successfully", func() {
		steadyHqConfig := config.SteadyHq{
			APIKey:    "steady-api-key",
			Title:     "Test Title",
			Episode:   "http://example.com/episode.mp3",
			Image:     "http://example.com/image.png",
			ShowNotes: tempFile.Name(),
		}

		// Overwrite the URL to use the test server
		targets.SetSteadyHqAPIURL(steadyHqTestServer.URL + "/api/v1/posts/audio_posts")

		err := targets.ScheduleSteadyHq(steadyHqConfig, "2025-07-08 12:00:00")

		Expect(err).Should(BeNil())
	})
})
