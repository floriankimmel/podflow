package backend_test

import (
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"github.com/floriankimmel/podflow/internal/backend"
	"testing"
)

func TestIdentityNumberWinsOverSlug(t *testing.T) {
	meta := backend.Metadata{Slug: "my-folder"}
	if got := backend.Identity(meta); got != "my-folder" {
		t.Fatalf("pre-number identity = %q, want slug", got)
	}
	meta.EpisodeNumber = "259"
	if got := backend.Identity(meta); got != "259" {
		t.Fatalf("numbered identity = %q, want 259", got)
	}
}

func TestNewUnconfiguredIsNil(t *testing.T) {
	if backend.New("", "key") != nil || backend.New("http://x", "") != nil {
		t.Fatal("unconfigured reporter must be nil")
	}
	var r *backend.Reporter
	// Must not panic.
	r.Report(backend.Metadata{EpisodeNumber: "1"}, "s3", backend.StatusDone)
}

func TestReportSendsStepAndAuth(t *testing.T) {
	var gotPath, gotKey string
	var gotBody map[string]any
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		gotPath = r.URL.Path
		gotKey = r.Header.Get("X-Workspace-Key")
		raw, _ := io.ReadAll(r.Body)
		_ = json.Unmarshal(raw, &gotBody)
		w.WriteHeader(http.StatusOK)
	}))
	defer server.Close()

	r := backend.New(server.URL, "secret")
	r.Report(backend.Metadata{EpisodeNumber: "259", Title: "Folge"}, "ftp_upload", backend.StatusInProgress)

	if gotPath != "/episodes/259/steps" {
		t.Fatalf("path = %q", gotPath)
	}
	if gotKey != "secret" {
		t.Fatalf("key = %q", gotKey)
	}
	if gotBody["step"] != "ftp_upload" || gotBody["status"] != "in_progress" {
		t.Fatalf("body = %v", gotBody)
	}
}

func TestReportNonFatalOnUnreachableAndError(t *testing.T) {
	// Unreachable server: must not panic or block the caller.
	r := backend.New("http://127.0.0.1:1", "secret")
	r.Report(backend.Metadata{EpisodeNumber: "1"}, "s3", backend.StatusDone)

	// Server error: must be swallowed.
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusInternalServerError)
	}))
	defer server.Close()
	r = backend.New(server.URL, "secret")
	r.Report(backend.Metadata{EpisodeNumber: "1"}, "s3", backend.StatusDone)
}
