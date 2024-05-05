package wordpress_test

import (
	"net/http/httptest"
	"os"
	"path/filepath"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"

	config "podflow/internal/configuration"
	"podflow/internal/targets/wordpress"
	testData "podflow/test/testdata"
)

var workingDir = filepath.Join(os.TempDir(), "podflow")

var _ = Describe("An wordpress episode can be", Ordered, func() {
	var wordpressTestServer *httptest.Server

	BeforeAll(func() {
		wordpressTestServer = wordpress.CreateWordPressTestServer()
	})
	AfterAll(func() {
		wordpressTestServer.Close()
	})
	It("scheduled successfully", func() {
		stateFilePath := filepath.Join(workingDir, "podflow.state.yml")
		stateFile, _ := os.Create(stateFilePath)

		filePath := filepath.Join(workingDir, "podflow.mp3")
		file, _ := os.Create(filePath)

		chapterFilePath := filepath.Join(workingDir, "podflow.chapters.txt")
		chapterFile, _ := os.Create(chapterFilePath)
		if err := os.WriteFile(chapterFilePath, []byte("00:01:01.517 Automated Test"), 0600); err != nil {
			panic(err)
		}

		defer os.Remove(stateFile.Name())
		defer os.Remove(file.Name())
		defer os.Remove(chapterFile.Name())

		step := config.Step{
			Wordpress: config.Wordpress{
				APIKey:  "apiKey",
				Server:  wordpressTestServer.URL,
				Image:   "wordpress.go",
				Episode: "episode.mp3",
				Chapter: chapterFilePath,
			},
		}
		title := "title"
		scheduledDate := "2021-07-10 00:00:00"

		stateIo := testData.TempStateFile{}
		_, err := wordpress.ScheduleEpisode(step.Wordpress, stateIo, title, "1", scheduledDate)

		Expect(err).Should(BeNil())
	})
})
