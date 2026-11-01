package cmd_test

import (
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"sync"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"

	cmd "podflow/internal/commands"
	config "podflow/internal/configuration"
	state "podflow/internal/state"
	testData "podflow/test/testdata"
)

// fullConfig configures every publish step so each one reports to the backend.
var fullConfig = config.Configuration{
	CurrentEpisode: "7",
	Files: []config.EpisodeFile{
		{Name: "Podflow", FileName: "{{folderName}}.mp3", Required: true},
	},
	Steps: []config.Step{
		{
			FTP: config.FTP{
				Delete: []config.FtpTargetFile{{Target: "old.mp3"}},
				Files:  []config.FtpFile{{Source: "a.mp3", Target: "a.mp3"}},
			},
			Download:  config.FTP{Files: []config.FtpFile{{Source: "a.mp3", Target: "a.mp3"}}},
			S3:        config.S3{Buckets: []config.S3Bucket{{Name: "bucket"}}},
			Wordpress: config.Wordpress{Server: "https://example.com"},
			SteadyHq:  config.SteadyHq{APIKey: "key"},
			Auphonic:  config.Auphonic{Title: "title", Files: []config.AuphonicFiles{{Episode: "e"}}},
		},
	},
}

// doneState marks every step already done locally, so publish takes the skip
// path (no network targets) while still re-reporting each step to the backend.
var doneState = state.State{
	Metadata:   state.Metadata{Title: "Persisted", EpisodeNumber: "9", ReleaseDate: "2026-11-05"},
	FTPDeleted: true, FTPUploaded: true, Downloaded: true, S3Uploaded: true,
	WordpressBlogCreated: true, SteadyHqCreated: true, AuphonicProduction: true,
}

func setupEpisodeDir() func() {
	if err := os.MkdirAll(workingDir, os.ModePerm); err != nil {
		panic(err)
	}
	paths := []string{
		filepath.Join(workingDir, "podflow.yml"),
		filepath.Join(workingDir, "podflow.mp3"),
		filepath.Join(workingDir, "podflow.state.yml"),
	}
	for _, p := range paths {
		f, _ := os.Create(p)
		f.Close()
	}
	return func() {
		for _, p := range paths {
			os.Remove(p)
		}
	}
}

var _ = Describe("Publish backend state sync", func() {
	AfterEach(func() {
		os.Unsetenv("PODFLOW_BACKEND_URL")
		os.Unsetenv("PODFLOW_WORKSPACE_KEY")
	})

	It("reports every step with identity and status to the backend", func() {
		cleanup := setupEpisodeDir()
		defer cleanup()

		type report struct {
			Path   string
			Step   string
			Status string
			Number string
		}
		var mu sync.Mutex
		var reports []report

		server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			raw, _ := io.ReadAll(r.Body)
			var body struct {
				Step     string `json:"step"`
				Status   string `json:"status"`
				Metadata struct {
					EpisodeNumber string `json:"episodeNumber"`
				} `json:"metadata"`
			}
			_ = json.Unmarshal(raw, &body)
			mu.Lock()
			reports = append(reports, report{r.URL.Path, body.Step, body.Status, body.Metadata.EpisodeNumber})
			mu.Unlock()
			w.WriteHeader(http.StatusOK)
		}))
		defer server.Close()

		os.Setenv("PODFLOW_BACKEND_URL", server.URL)
		os.Setenv("PODFLOW_WORKSPACE_KEY", "test-key")

		io := testData.TempConfigurationFile{}
		Expect(io.Write(fullConfig)).Should(Succeed())
		stateIo := testData.TempStateFile{}
		Expect(stateIo.Write(doneState)).Should(Succeed())

		Expect(cmd.Publish(io, stateIo, MockInput{}, workingDir)).Should(Succeed())

		mu.Lock()
		defer mu.Unlock()
		var steps []string
		for _, r := range reports {
			Expect(r.Path).Should(Equal("/episodes/9/steps"))
			Expect(r.Status).Should(Equal("done"))
			Expect(r.Number).Should(Equal("9"))
			steps = append(steps, r.Step)
		}
		Expect(steps).Should(Equal([]string{
			"ftp_delete", "ftp_upload", "download", "s3", "wordpress", "steady", "auphonic",
		}))
	})

	It("completes publish and keeps local state when the backend is unreachable", func() {
		cleanup := setupEpisodeDir()
		defer cleanup()

		os.Setenv("PODFLOW_BACKEND_URL", "http://127.0.0.1:1")
		os.Setenv("PODFLOW_WORKSPACE_KEY", "test-key")

		io := testData.TempConfigurationFile{}
		Expect(io.Write(fullConfig)).Should(Succeed())
		stateIo := testData.TempStateFile{}
		Expect(stateIo.Write(doneState)).Should(Succeed())

		Expect(cmd.Publish(io, stateIo, MockInput{}, workingDir)).Should(Succeed())

		persisted, err := stateIo.Read()
		Expect(err).Should(BeNil())
		Expect(persisted.Metadata).Should(Equal(doneState.Metadata))
		Expect(persisted.FTPUploaded).Should(BeTrue())
	})

	It("does not report anything when the backend is not configured", func() {
		cleanup := setupEpisodeDir()
		defer cleanup()

		io := testData.TempConfigurationFile{}
		Expect(io.Write(fullConfig)).Should(Succeed())
		stateIo := testData.TempStateFile{}
		Expect(stateIo.Write(doneState)).Should(Succeed())

		Expect(cmd.Publish(io, stateIo, MockInput{}, workingDir)).Should(Succeed())
	})
})
