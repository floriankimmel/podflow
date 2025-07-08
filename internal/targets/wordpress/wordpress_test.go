package wordpress_test

import (
	"encoding/json"
	"os"
	"path/filepath"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"

	config "podflow/internal/configuration"
	"podflow/internal/state"
	"podflow/internal/targets/wordpress"
	testData "podflow/test/testdata"
)

var workingDir = filepath.Join(os.TempDir(), "podflow")

var _ = Describe("An wordpress episode can be", Ordered, func() {
	var wordpressTestServer *wordpress.WordpressTestServer
	var stateFile *os.File
	var chapterFile *os.File
	var file *os.File

	BeforeEach(func() {
		stateFilePath := filepath.Join(workingDir, "podflow.state.yml")
		stateFile, _ = os.Create(stateFilePath)

		filePath := filepath.Join(workingDir, "podflow.mp3")
		file, _ = os.Create(filePath)

		chapterFilePath := filepath.Join(workingDir, "podflow.chapters.txt")
		chapterFile, _ = os.Create(chapterFilePath)
		if err := os.WriteFile(chapterFilePath, []byte("00:01:01.517 Automated Test"), 0600); err != nil {
			panic(err)
		}

		WordpressID := "4"
		PodloveID := "2"
		FeaturedMediaID := "3"

		wordpressTestServer = wordpress.CreateWordPressTestServer(WordpressID, PodloveID, FeaturedMediaID)
	})

	AfterEach(func() {
		wordpressTestServer.Server.Close()
		os.Remove(stateFile.Name())
		os.Remove(file.Name())
		os.Remove(chapterFile.Name())
	})

	It("scheduled successfully for the second time", func() {
		step := config.Step{
			Wordpress: config.Wordpress{
				APIKey:  "apiKey",
				Server:  wordpressTestServer.Server.URL,
				Image:   "wordpress.go",
				Episode: "episode.mp3",
				Chapter: chapterFile.Name(),
			},
		}
		title := "title"
		scheduledDate := "2021-07-10 00:00:00"

		stateIo := testData.TempStateFile{}
		if err := stateIo.Write(state.State{
			Wordpress: state.Wordpress{
				WordpressID:     wordpressTestServer.WordpressID,
				PodloveID:       json.Number(wordpressTestServer.PodloveID),
				FeaturedMediaID: wordpressTestServer.FeaturedMediaID,
			},
		}); err != nil {
			panic(err)
		}

		episode, err := wordpress.ScheduleEpisode(step.Wordpress, stateIo, title, "1", scheduledDate)

		Expect(err).Should(BeNil())
		Expect(episode.WordpressID).Should(Equal(wordpressTestServer.WordpressID))
		Expect(wordpressTestServer.CreateCalled).Should(BeFalse())
	})

	It("scheduled successfully", func() {
		step := config.Step{
			Wordpress: config.Wordpress{
				APIKey:  "apiKey",
				Server:  wordpressTestServer.Server.URL,
				Image:   "wordpress.go",
				Episode: "episode.mp3",
				Chapter: chapterFile.Name(),
			},
		}
		title := "title"
		scheduledDate := "2021-07-10 00:00:00"

		stateIo := testData.TempStateFile{}
		episode, err := wordpress.ScheduleEpisode(step.Wordpress, stateIo, title, "1", scheduledDate)

		Expect(err).Should(BeNil())
		Expect(episode.WordpressID).Should(Equal(wordpressTestServer.WordpressID))
		Expect(wordpressTestServer.CreateCalled).Should(BeTrue())
	})
})
