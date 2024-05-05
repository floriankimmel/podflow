package wordpress

import (
	"net/http"
	"net/http/httptest"
)

type handler struct{}

func (h handler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	switch r.URL.Path {
	case "/wp-json/podlove/v2/episodes/2":
		{
			if _, err := w.Write([]byte(`{"post_1": "1" }`)); err != nil {
				w.WriteHeader(500)
			}
		}
	case "/wp-json/wp/v2/episodes/":
		{
			if _, err := w.Write([]byte(`{}`)); err != nil {
				w.WriteHeader(500)
			}
		}
	case "/wp-json/podlove/v2/chapters/2":
	case "/wp-json/podlove/v2/episodes/2/media/3/enable":
	case "/wp-json/podlove/v2/episodes/2/media/2/enable":
		if _, err := w.Write([]byte(`{}`)); err != nil {
			w.WriteHeader(500)
		}
	case "/wp-json/podlove/v2/episodes/":
		if _, err := w.Write([]byte(`{"id": "2" }`)); err != nil {
			w.WriteHeader(500)
		}
	case "/wp-json/podlove/v2/chapters/":
		if _, err := w.Write([]byte(`{}`)); err != nil {
			w.WriteHeader(500)
		}
	case "/wp-json/wp/v2/media/":
		if _, err := w.Write([]byte(`{"id": "3"}`)); err != nil {
			w.WriteHeader(500)
		}
	default:
		w.WriteHeader(404)
	}
}

func CreateWordPressTestServer() *httptest.Server {
	mux := http.NewServeMux()
	mux.HandleFunc("/wp-json/wp/v2/episodes/", handler{}.ServeHTTP)
	mux.HandleFunc("/wp-json/podlove/v2/episodes/", handler{}.ServeHTTP)
	mux.HandleFunc("/wp-json/podlove/v2/episodes/2", handler{}.ServeHTTP)
	mux.HandleFunc("/wp-json/podlove/v2/chapters/", handler{}.ServeHTTP)
	mux.HandleFunc("/wp-json/wp/v2/media/", handler{}.ServeHTTP)
	mux.HandleFunc("/wp-json/podlove/v2/episodes/2/media/2/enable", handler{}.ServeHTTP)
	mux.HandleFunc("/wp-json/podlove/v2/episodes/2/media/3/enable", handler{}.ServeHTTP)
	mux.HandleFunc("/wp-json/podlove/v2/chapters/2", handler{}.ServeHTTP)
	return httptest.NewServer(mux)
}
