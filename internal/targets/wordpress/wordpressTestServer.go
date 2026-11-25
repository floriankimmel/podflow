package wordpress

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync"
)

// RecordedRequest is one request the test server received.
type RecordedRequest struct {
	Method string
	Path   string
	// Fields is the JSON body; nil for empty or multipart bodies.
	Fields map[string]any
}

// WordpressTestServer fakes WordPress with Podlove and records every request.
type WordpressTestServer struct {
	PodloveID       string
	WordpressID     string
	FeaturedMediaID string
	Server          *httptest.Server

	mu       sync.Mutex
	requests []RecordedRequest
}

// Requests returns the recorded requests, optionally only those to path.
func (h *WordpressTestServer) Requests(path ...string) []RecordedRequest {
	h.mu.Lock()
	defer h.mu.Unlock()
	if len(path) == 0 {
		return append([]RecordedRequest(nil), h.requests...)
	}
	var matching []RecordedRequest
	for _, r := range h.requests {
		if r.Path == path[0] {
			matching = append(matching, r)
		}
	}
	return matching
}

// Field returns the last value sent for field in a POST to path.
func (h *WordpressTestServer) Field(path, field string) any {
	var value any
	for _, r := range h.Requests(path) {
		if v, ok := r.Fields[field]; ok && r.Method == http.MethodPost {
			value = v
		}
	}
	return value
}

func (h *WordpressTestServer) PodloveEpisodePath() string { return podloveURLPath + h.PodloveID }
func (h *WordpressTestServer) PostPath() string           { return wpURLPath + h.WordpressID }
func (h *WordpressTestServer) ChaptersPath() string       { return podloveChaptersURLPath + h.PodloveID }
func (h *WordpressTestServer) CreatePath() string         { return podloveURLPath }

func (h *WordpressTestServer) record(r *http.Request) {
	body, _ := io.ReadAll(r.Body)
	var fields map[string]any
	if strings.Contains(r.Header.Get("Content-Type"), "json") && len(body) > 0 {
		_ = json.Unmarshal(body, &fields)
	}
	h.mu.Lock()
	h.requests = append(h.requests, RecordedRequest{Method: r.Method, Path: r.URL.Path, Fields: fields})
	h.mu.Unlock()
}

func (h *WordpressTestServer) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	h.record(r)
	write := func(v string) { _, _ = w.Write([]byte(v)) }
	mediaPrefix := h.PodloveEpisodePath() + "/media/"

	switch path := r.URL.Path; {
	case path == h.CreatePath():
		write(fmt.Sprintf(`{"id": %s}`, h.PodloveID))
	case path == h.PodloveEpisodePath():
		write(fmt.Sprintf(`{"post_id": "%s"}`, h.WordpressID))
	case path == h.PostPath(), path == h.ChaptersPath():
		write("{}")
	case strings.HasPrefix(path, mediaPrefix) && strings.HasSuffix(path, "/enable"):
		write("{}")
	// The client posts to /media like WordPress expects; Go 1.22+ answers a
	// POST to a missing trailing-slash route with a 307 it cannot follow.
	case path == mediaURLPath, path == mediaURLPath+"/":
		write(fmt.Sprintf(`{"id": "%s"}`, h.FeaturedMediaID))
	default:
		w.WriteHeader(http.StatusNotFound)
	}
}

func CreateWordPressTestServer(wordpressID string, podloveID string, featuredMediaID string) *WordpressTestServer {
	server := &WordpressTestServer{
		WordpressID:     wordpressID,
		PodloveID:       podloveID,
		FeaturedMediaID: featuredMediaID,
	}
	server.Server = httptest.NewServer(server)
	return server
}
