// Package backend reports publish progress to the shared podflow backend.
// All calls are best-effort: failures are logged and never propagate to the
// publish pipeline, so the CLI stays fully functional offline.
package backend

import (
	"bytes"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"time"
)

const (
	StatusPending    = "pending"
	StatusInProgress = "in_progress"
	StatusDone       = "done"
	StatusFailed     = "failed"
)

type Metadata struct {
	EpisodeNumber string `json:"episodeNumber,omitempty"`
	Slug          string `json:"slug,omitempty"`
	Title         string `json:"title,omitempty"`
	ReleaseDate   string `json:"releaseDate,omitempty"`
	Profile       string `json:"profile,omitempty"`
}

// Identity returns the stable episode identity: the episode number once
// assigned, the folder slug before that.
func Identity(meta Metadata) string {
	if meta.EpisodeNumber != "" {
		return meta.EpisodeNumber
	}
	return meta.Slug
}

type Reporter struct {
	url    string
	key    string
	client *http.Client
}

// New returns a Reporter, or nil when the backend is not configured.
// A nil Reporter is safe to use: Report becomes a no-op.
func New(url string, workspaceKey string) *Reporter {
	if url == "" || workspaceKey == "" {
		return nil
	}
	return &Reporter{
		url:    url,
		key:    workspaceKey,
		client: &http.Client{Timeout: 5 * time.Second},
	}
}

type stepReport struct {
	Step     string   `json:"step"`
	Status   string   `json:"status"`
	Metadata Metadata `json:"metadata"`
}

// Report sends one step status to the backend. Best-effort: any error is
// logged and swallowed.
func (r *Reporter) Report(meta Metadata, step string, status string) {
	if r == nil {
		return
	}
	identity := Identity(meta)
	if identity == "" {
		return
	}
	body, err := json.Marshal(stepReport{Step: step, Status: status, Metadata: meta})
	if err != nil {
		log.Printf("backend report skipped: %v", err)
		return
	}
	endpoint := fmt.Sprintf("%s/episodes/%s/steps", r.url, identity)
	req, err := http.NewRequest(http.MethodPost, endpoint, bytes.NewReader(body))
	if err != nil {
		log.Printf("backend report skipped: %v", err)
		return
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("X-Workspace-Key", r.key)

	resp, err := r.client.Do(req)
	if err != nil {
		log.Printf("backend unreachable (publish continues): %v", err)
		return
	}
	defer resp.Body.Close()
	if resp.StatusCode >= 300 {
		log.Printf("backend rejected step report (%s %s): HTTP %d", step, status, resp.StatusCode)
	}
}
