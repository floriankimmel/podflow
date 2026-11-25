package cmd_test

import (
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"sync/atomic"
	"time"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
	yaml "gopkg.in/yaml.v3"

	cmd "github.com/floriankimmel/podflow/internal/commands"
	state "github.com/floriankimmel/podflow/internal/state"
	"github.com/floriankimmel/podflow/internal/targets/wordpress"
)

// folderState keeps <folder>.state.yml in a given episode folder.
type folderState struct{ dir string }

func (f folderState) GetStateFilePath() string {
	return filepath.Join(f.dir, filepath.Base(f.dir)+".state.yml")
}
func (f folderState) Read() (state.State, error) {
	var s state.State
	data, err := os.ReadFile(f.GetStateFilePath())
	if err != nil {
		return s, err
	}
	return s, yaml.Unmarshal(data, &s)
}
func (f folderState) Write(s state.State) error {
	data, err := yaml.Marshal(s)
	if err != nil {
		return err
	}
	return os.WriteFile(f.GetStateFilePath(), data, 0600)
}

// The same fixture pins the desktop app's PublishInput encoding.
var publishFixture = filepath.Join("..", "..", "desktop", "Tests", "fixtures", "publish.json")

var _ = Describe("publish-episode", func() {
	var dir string

	BeforeEach(func() {
		dir = filepath.Join(GinkgoT().TempDir(), "371")
		Expect(os.MkdirAll(dir, 0755)).To(Succeed())
		for _, name := range []string{"shownotes.md", "seo.md", "cover.png", "wordpress.jpg"} {
			Expect(os.WriteFile(filepath.Join(dir, name), []byte("x"), 0600)).To(Succeed())
		}
		fixture, err := os.ReadFile(publishFixture)
		Expect(err).ToNot(HaveOccurred())
		Expect(os.WriteFile(filepath.Join(dir, "publish.json"), fixture, 0600)).To(Succeed())
	})

	It("reads publish.json and derives the Cover upload and website post", func() {
		input, err := cmd.ReadEpisodeInput(filepath.Join(dir, "publish.json"))
		Expect(err).ToNot(HaveOccurred())
		Expect(input.ReleaseDate).To(Equal(time.Date(2026, 11, 27, 8, 0, 0, 0, time.UTC)))

		cfg := input.Configuration()
		Expect(cfg.Steps).To(HaveLen(2))
		ftp := cfg.Steps[0].FTP
		Expect(ftp.Host).To(Equal("ftp.example.test"))
		Expect(ftp.Port).To(Equal("2121"))
		Expect(ftp.Username).To(Equal("{{env.FTP_USER}}"))
		Expect(ftp.Files[0].Source).To(Equal("cover.png"))
		Expect(ftp.Files[0].Target).To(Equal("371_grossglockner.png"))
		wp := cfg.Steps[1].Wordpress
		Expect(wp.APIKey).To(Equal("{{env.WP_KEY}}"))
		Expect(wp.Poster).To(Equal("http://files.example.test/data/371_grossglockner.png"))
		Expect(wp.Episode).To(Equal("371_grossglockner"))
		Expect(wp.Image).To(Equal("wordpress.jpg"))
		Expect(wp.ContentFile).To(Equal("seo.md"))
	})

	It("rejects a publish.json with missing fields", func() {
		path := filepath.Join(dir, "bad.json")
		Expect(os.WriteFile(path, []byte(`{"episodeNumber":"371"}`), 0600)).To(Succeed())
		_, err := cmd.ReadEpisodeInput(path)
		Expect(err).To(MatchError(ContainSubstring("releaseDate")))
		Expect(err).To(MatchError(ContainSubstring("title")))
	})

	It("schedules the post in local time, keeps progress and reports nothing", func() {
		var backendCalls atomic.Int32
		backend := httptest.NewServer(http.HandlerFunc(func(http.ResponseWriter, *http.Request) { backendCalls.Add(1) }))
		defer backend.Close()
		GinkgoT().Setenv("PODFLOW_BACKEND_URL", backend.URL)
		GinkgoT().Setenv("PODFLOW_WORKSPACE_KEY", "wk")
		GinkgoT().Setenv("WP_KEY", "wp")

		site := wordpress.CreateWordPressTestServer("4", "2", "3")
		defer site.Server.Close()

		input, err := cmd.ReadEpisodeInput(filepath.Join(dir, "publish.json"))
		Expect(err).ToNot(HaveOccurred())
		input.WordpressServer = site.Server.URL

		previous, err := os.Getwd()
		Expect(err).ToNot(HaveOccurred())
		Expect(os.Chdir(dir)).To(Succeed()) // the CLI runs in the episode folder
		DeferCleanup(os.Chdir, previous)

		stateIo := folderState{dir: dir}
		// The Cover is already on the server: only the WordPress step runs.
		Expect(stateIo.Write(state.State{FTPUploaded: true})).To(Succeed())

		Expect(cmd.PublishEpisode(input, stateIo, dir)).To(Succeed())

		local := input.ReleaseDate.Local().Format("2006-01-02 15:04:05")
		Expect(site.Field(site.PostPath(), "date")).To(Equal(local))
		Expect(site.Field(site.PodloveEpisodePath(), "poster")).To(Equal("http://files.example.test/data/371_grossglockner.png"))

		saved, err := stateIo.Read()
		Expect(err).ToNot(HaveOccurred())
		Expect(saved.FTPUploaded).To(BeTrue())
		Expect(saved.WordpressBlogCreated).To(BeTrue())
		Expect(saved.Wordpress.WordpressID).To(Equal("4"))
		Expect(saved.Metadata).To(Equal(state.Metadata{EpisodeNumber: "371", Title: "Großglockner", ReleaseDate: local}))
		Expect(backendCalls.Load()).To(BeZero())
	})
})
