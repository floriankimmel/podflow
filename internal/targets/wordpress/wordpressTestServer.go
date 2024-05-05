package wordpress

import (
	"fmt"
	"net/http"
	"net/http/httptest"
)

type WordpressTestServer struct {
	PodloveID       string
	WordpressID     string
	FeaturedMediaID string
	Server          *httptest.Server
	CreateCalled    bool
}

func WriteJSON(w http.ResponseWriter, v string) {
	if _, err := w.Write([]byte(v)); err != nil {
		w.WriteHeader(500)
	}
}
func (h *WordpressTestServer) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	podloveURL := fmt.Sprintf("/wp-json/podlove/v2/episodes/%s", h.PodloveID)
	episodeURL := fmt.Sprintf("/wp-json/wp/v2/episodes/%s", h.WordpressID)
	chapterURL := fmt.Sprintf("/wp-json/podlove/v2/chapters/%s", h.PodloveID)
	mediaURL := fmt.Sprintf("/wp-json/podlove/v2/episodes/%s/media", h.PodloveID)

	switch r.URL.Path {
	case podloveURL:
		WriteJSON(w, "{\"post_id\": \""+h.WordpressID+"\"}")
	case episodeURL:
	case "/wp-json/wp/v2/episodes/":
		WriteJSON(w, "{}")
	case "/wp-json/podlove/v2/episodes/":
		{
			WriteJSON(w, "{\"id\": "+h.PodloveID+"}")
			h.CreateCalled = true
		}
	case chapterURL:
	case mediaURL + "/3/enable":
	case mediaURL + "/2/enable":
		WriteJSON(w, "{}")

	case "/wp-json/podlove/v2/chapters/":
		WriteJSON(w, "{}")
	case "/wp-json/wp/v2/media/":
		WriteJSON(w, "{\"id\": \""+h.FeaturedMediaID+"\"}")
	default:
		w.WriteHeader(404)
	}
}

func CreateWordPressTestServer(WordpressID string, PodloveID string, FeatureMediaID string) *WordpressTestServer {
	wordpressTestServer := &WordpressTestServer{
		WordpressID:     WordpressID,
		PodloveID:       PodloveID,
		FeaturedMediaID: FeatureMediaID,
	}
	mux := http.NewServeMux()
	mux.HandleFunc("/wp-json/wp/v2/episodes/", wordpressTestServer.ServeHTTP)
	mux.HandleFunc("/wp-json/podlove/v2/episodes/", wordpressTestServer.ServeHTTP)
	mux.HandleFunc("/wp-json/podlove/v2/episodes/"+PodloveID, wordpressTestServer.ServeHTTP)
	mux.HandleFunc("/wp-json/podlove/v2/chapters/", wordpressTestServer.ServeHTTP)
	mux.HandleFunc("/wp-json/wp/v2/media/", wordpressTestServer.ServeHTTP)
	mux.HandleFunc("/wp-json/podlove/v2/episodes/"+PodloveID+"/media/{media}/enable", wordpressTestServer.ServeHTTP)
	mux.HandleFunc("/wp-json/podlove/v2/chapters/"+PodloveID, wordpressTestServer.ServeHTTP)
	wordpressTestServer.Server = httptest.NewServer(mux)

	return wordpressTestServer
}
