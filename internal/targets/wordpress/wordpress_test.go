package wordpress_test

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	config "podflow/internal/configuration"
	"podflow/internal/targets/wordpress"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("An wordpress post can be", Ordered, func() {

    var wordpressTestServer *httptest.Server

    It("scheduled successfully", func() {
        step := config.Step{
            Wordpress: config.Wordpress{
                ApiKey: "apiKey",
                Server: wordpressTestServer.URL,
                Image: "wordpress.go",
                Episode: "episode.mp3",
            },
        }
        title := "title"
        scheduledDate := "2021-07-10 00:00:00"


        successfulProductions, err := wordpress.ScheduleEpisode(step, title, "1", scheduledDate)

        Expect(err).Should(BeNil())
        Expect(successfulProductions.Id).Should(Equal("1"))
        Expect(successfulProductions.PostId).Should(Equal("11"))

    })

    BeforeAll(func() {
        mux := http.NewServeMux()

        mux.HandleFunc("/wp-json/wp/v2/media", func(w http.ResponseWriter, r *http.Request) {

        })
        mux.HandleFunc("/wp-json/podlove/v2/episodes/1", func(w http.ResponseWriter, r *http.Request) {
            if r.Header.Get("Authorization") != "Basic apiKey" {
                w.WriteHeader(500)
                return
            }

            if r.Header.Get("Content-type") != "application/json" {
                w.WriteHeader(500)
                return
            }

            if r.Method == "GET" {
                podloveEpisode := wordpress.PodloveEpisode{
                    PostId: "11",
                }
                response, err := json.Marshal(podloveEpisode)

                if err != nil {
                    w.WriteHeader(500)
                    return
                }

                if _, err := w.Write(response); err != nil {
                    w.WriteHeader(500)
                    return
                }
            }
        })
        mux.HandleFunc("/wp-json/podlove/v2/episodes", func(w http.ResponseWriter, r *http.Request) {
            if r.Header.Get("Authorization") != "Basic apiKey" {
                w.WriteHeader(500)
                return
            }

            if r.Method == "POST" {
                podloveEpisode := wordpress.PodloveEpisode{
                    Id: "1",
                }
                response, err := json.Marshal(podloveEpisode)

                if err != nil {
                    w.WriteHeader(500)
                    return
                }

                if _, err := w.Write(response); err != nil {
                    w.WriteHeader(500)
                    return
                }

                w.WriteHeader(201)

            }
        })
        wordpressTestServer = httptest.NewServer(mux)

    })

    AfterAll(func() {
        wordpressTestServer.Close()
    })



})
