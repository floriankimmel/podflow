package wordpress_test

import (
	"net/http"
	"os"
	"path/filepath"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"

	config "github.com/floriankimmel/podflow/internal/configuration"
	"github.com/floriankimmel/podflow/internal/targets/wordpress"
)

var _ = Describe("An episode's website post", func() {
	var server *wordpress.WordpressTestServer
	var dir string
	var post wordpress.Post
	var saved []wordpress.IDs
	save := func(ids wordpress.IDs) error { saved = append(saved, ids); return nil }

	BeforeEach(func() {
		dir = GinkgoT().TempDir()
		write := func(name, content string) string {
			path := filepath.Join(dir, name)
			Expect(os.WriteFile(path, []byte(content), 0600)).To(Succeed())
			return path
		}
		server = wordpress.CreateWordPressTestServer("4", "2", "3")
		saved = nil
		post = wordpress.Post{
			Title:             "Großglockner",
			EpisodeNumber:     "371",
			ReleaseDate:       "2026-11-27 09:00:00",
			AudioSlug:         "371_grossglockner",
			ShowNotesFile:     write("shownotes.md", "# Folge 371"),
			FeaturedImageFile: write("featured.png", "png"),
			CoverURL:          "http://files.example.test/data/371_grossglockner.png",
			ChaptersFile:      write("chapters.txt", "00:01:01.517 Start\n00:10:00.000 Gipfel erreicht"),
			SEO:               wordpress.SEOTexts{MetaDescription: "Laufen auf 3.798 Meter", FocusKeywords: "Glocknerlauf"},
		}
	})

	AfterEach(func() { server.Server.Close() })

	site := func() wordpress.Site { return wordpress.Site{Server: server.Server.URL, APIKey: "apiKey"} }

	It("is created, filled and scheduled", func() {
		ids, err := wordpress.ScheduleEpisode(site(), post, wordpress.IDs{}, save)

		Expect(err).ToNot(HaveOccurred())
		Expect(ids).To(Equal(wordpress.IDs{PodloveID: "2", WordpressID: "4", FeaturedMediaID: "3"}))
		Expect(saved).To(Equal([]wordpress.IDs{
			{PodloveID: "2", WordpressID: "4"},
			{PodloveID: "2", WordpressID: "4", FeaturedMediaID: "3"},
		}))

		episode, wp := server.PodloveEpisodePath(), server.PostPath()
		Expect(server.Field(episode, "title")).To(Equal("LEP#371 - Großglockner"))
		Expect(server.Field(episode, "slug")).To(Equal("371_grossglockner"))
		Expect(server.Field(episode, "number")).To(Equal("371"))
		Expect(server.Field(episode, "poster")).To(Equal(post.CoverURL))
		Expect(server.Field(episode, "episode_poster")).To(Equal(post.CoverURL))
		Expect(server.Field(episode, "summary")).To(Equal("Laufen auf 3.798 Meter"))

		Expect(server.Field(wp, "slug")).To(Equal("371"))
		Expect(server.Field(wp, "status")).To(Equal("future"))
		Expect(server.Field(wp, "date")).To(Equal("2026-11-27 09:00:00"))
		Expect(server.Field(wp, "featured_media")).To(Equal("3"))
		Expect(server.Field(wp, "content")).To(ContainSubstring("Folge 371"))
		Expect(server.Field(wp, "meta")).To(Equal(map[string]any{
			"_yoast_wpseo_focuskw":  "Glocknerlauf",
			"_yoast_wpseo_metadesc": "Laufen auf 3.798 Meter",
		}))

		chapters := server.Requests(server.ChaptersPath())
		Expect(chapters).To(HaveLen(1))
		Expect(chapters[0].Method).To(Equal(http.MethodPut))
		Expect(chapters[0].Fields["chapters"]).To(Equal([]any{
			map[string]any{"start": "00:01:01.517", "title": "Start"},
			map[string]any{"start": "00:10:00.000", "title": "Gipfel erreicht"},
		}))
		Expect(server.Requests(server.PodloveEpisodePath() + "/media/2/enable")).To(HaveLen(1))
		Expect(server.Requests(server.PodloveEpisodePath() + "/media/3/enable")).To(HaveLen(1))
	})

	It("resumes without creating the post or uploading the image again", func() {
		ids := wordpress.IDs{PodloveID: "2", WordpressID: "4", FeaturedMediaID: "3"}
		_, err := wordpress.ScheduleEpisode(site(), post, ids, save)

		Expect(err).ToNot(HaveOccurred())
		Expect(server.Requests(server.CreatePath())).To(BeEmpty())
		Expect(server.Requests("/wp-json/wp/v2/media")).To(BeEmpty())
		Expect(saved).To(BeEmpty())
	})

	It("skips SEO settings and summary without SEO texts", func() {
		post.SEO = wordpress.SEOTexts{}
		_, err := wordpress.ScheduleEpisode(site(), post, wordpress.IDs{}, save)

		Expect(err).ToNot(HaveOccurred())
		Expect(server.Field(server.PostPath(), "meta")).To(BeNil())
		Expect(server.Field(server.PodloveEpisodePath(), "summary")).To(BeNil())
	})

	It("returns an error instead of panicking when WordPress is unreachable", func() {
		unreachable := wordpress.Site{Server: "http://127.0.0.1:1", APIKey: "apiKey"}
		var err error
		Expect(func() { _, err = wordpress.ScheduleEpisode(unreachable, post, wordpress.IDs{}, save) }).ToNot(Panic())
		Expect(err).To(HaveOccurred())
	})

	It("sends no chapters when the chapters file is missing", func() {
		post.ChaptersFile = filepath.Join(dir, "missing.txt")
		_, err := wordpress.ScheduleEpisode(site(), post, wordpress.IDs{PodloveID: "2", WordpressID: "4", FeaturedMediaID: "3"}, save)

		Expect(err).ToNot(HaveOccurred())
		chapters := server.Requests(server.ChaptersPath())
		Expect(chapters).To(HaveLen(1))
		Expect(chapters[0].Fields["chapters"]).To(BeEmpty())
	})

	It("reads its SEO texts from the configured content file", func() {
		Expect(os.WriteFile(filepath.Join(dir, "content-371.md"),
			[]byte("**Meta-Description:**\nBeschreibung\n\n**Focus Keywords:**\n\n**Facebook OG Title:**\nTitel\n"), 0600)).To(Succeed())
		post, err := wordpress.NewPost(config.Wordpress{
			ContentFile: filepath.Join(dir, "content-{{episodeNumber}}.md"),
			Episode:     "371_grossglockner",
			Poster:      "http://cover",
		}, "Großglockner", "371", "2026-11-27 09:00:00")

		Expect(err).ToNot(HaveOccurred())
		Expect(post.SEO).To(Equal(wordpress.SEOTexts{MetaDescription: "Beschreibung"}))
		Expect(post.AudioSlug).To(Equal("371_grossglockner"))
		Expect(post.CoverURL).To(Equal("http://cover"))
	})
})
