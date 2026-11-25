package main

import (
	"crypto/subtle"
	"encoding/json"
	"errors"
	"log"
	"net/http"
	"strings"
)

type Server struct {
	store        *Store
	workspaceKey string
	mux          *http.ServeMux
}

func NewServer(store *Store, workspaceKey string) *Server {
	s := &Server{store: store, workspaceKey: workspaceKey, mux: http.NewServeMux()}
	s.mux.HandleFunc("/health", s.handleHealth)
	s.mux.HandleFunc("/episodes", s.auth(s.handleEpisodes))
	s.mux.HandleFunc("/episodes/", s.auth(s.handleEpisode))
	return s
}

func (s *Server) ServeHTTP(w http.ResponseWriter, r *http.Request) { s.mux.ServeHTTP(w, r) }

func (s *Server) handleHealth(w http.ResponseWriter, _ *http.Request) {
	writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
}

// auth checks the shared workspace key (X-Workspace-Key or Authorization: Bearer).
func (s *Server) auth(next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		key := r.Header.Get("X-Workspace-Key")
		if key == "" {
			if h := r.Header.Get("Authorization"); strings.HasPrefix(h, "Bearer ") {
				key = strings.TrimPrefix(h, "Bearer ")
			}
		}
		if s.workspaceKey == "" ||
			subtle.ConstantTimeCompare([]byte(key), []byte(s.workspaceKey)) != 1 {
			writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "invalid workspace key"})
			return
		}
		next(w, r)
	}
}

func (s *Server) handleEpisodes(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		writeJSON(w, http.StatusMethodNotAllowed, map[string]string{"error": "method not allowed"})
		return
	}
	episodes, err := s.store.List()
	if err != nil {
		serverError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, episodes)
}

type stepReport struct {
	Step     string   `json:"step"`
	Status   string   `json:"status"`
	Metadata Metadata `json:"metadata"`
}

// Routes:
//
//	GET    /episodes/{number}          episode with steps
//	DELETE /episodes/{number}          delete episode with steps
//	POST   /episodes/{number}/steps    upsert a step status (creates episode on first report)
//	POST   /episodes/{number}/metadata upsert metadata (profile, title, ...)
//
// The episode number in the path is the episode's identity; it overrides any
// episodeNumber in the request body.
func (s *Server) handleEpisode(w http.ResponseWriter, r *http.Request) {
	rest := strings.TrimPrefix(r.URL.Path, "/episodes/")
	parts := strings.SplitN(rest, "/", 2)
	number := parts[0]
	if number == "" {
		writeJSON(w, http.StatusNotFound, map[string]string{"error": "episode number required"})
		return
	}
	sub := ""
	if len(parts) == 2 {
		sub = parts[1]
	}

	switch {
	case sub == "" && r.Method == http.MethodGet:
		ep, err := s.store.Get(number)
		if errors.Is(err, ErrNotFound) {
			writeJSON(w, http.StatusNotFound, map[string]string{"error": "episode not found"})
			return
		}
		if err != nil {
			serverError(w, err)
			return
		}
		writeJSON(w, http.StatusOK, ep)

	case sub == "" && r.Method == http.MethodDelete:
		err := s.store.Delete(number)
		if errors.Is(err, ErrNotFound) {
			writeJSON(w, http.StatusNotFound, map[string]string{"error": "episode not found"})
			return
		}
		if err != nil {
			serverError(w, err)
			return
		}
		writeJSON(w, http.StatusOK, map[string]string{"status": "deleted"})

	case sub == "steps" && r.Method == http.MethodPost:
		var report stepReport
		if err := json.NewDecoder(r.Body).Decode(&report); err != nil {
			writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid json"})
			return
		}
		meta := report.Metadata
		meta.EpisodeNumber = number
		ep, err := s.store.UpsertStep(meta, report.Step, report.Status)
		if err != nil {
			if errors.Is(err, ErrInvalidStatus) || strings.Contains(err.Error(), "required") {
				writeJSON(w, http.StatusBadRequest, map[string]string{"error": err.Error()})
				return
			}
			serverError(w, err)
			return
		}
		writeJSON(w, http.StatusOK, ep)

	case sub == "metadata" && r.Method == http.MethodPost:
		var meta Metadata
		if err := json.NewDecoder(r.Body).Decode(&meta); err != nil {
			writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid json"})
			return
		}
		meta.EpisodeNumber = number
		ep, err := s.store.UpsertMetadata(meta)
		if err != nil {
			serverError(w, err)
			return
		}
		writeJSON(w, http.StatusOK, ep)

	default:
		writeJSON(w, http.StatusNotFound, map[string]string{"error": "not found"})
	}
}

func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(v)
}

func serverError(w http.ResponseWriter, err error) {
	log.Printf("server error: %v", err)
	writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "internal error"})
}
