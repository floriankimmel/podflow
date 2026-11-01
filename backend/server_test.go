package main

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"path/filepath"
	"testing"
)

const testKey = "test-workspace-key"

func newTestServer(t *testing.T) *Server {
	t.Helper()
	store, err := NewStore(filepath.Join(t.TempDir(), "test.db"))
	if err != nil {
		t.Fatalf("store: %v", err)
	}
	t.Cleanup(func() { _ = store.Close() })
	return NewServer(store, testKey)
}

func request(t *testing.T, s *Server, method, path, key string, body any) *httptest.ResponseRecorder {
	t.Helper()
	var buf bytes.Buffer
	if body != nil {
		if err := json.NewEncoder(&buf).Encode(body); err != nil {
			t.Fatal(err)
		}
	}
	req := httptest.NewRequest(method, path, &buf)
	if key != "" {
		req.Header.Set("X-Workspace-Key", key)
	}
	rec := httptest.NewRecorder()
	s.ServeHTTP(rec, req)
	return rec
}

func TestHealthNoAuth(t *testing.T) {
	s := newTestServer(t)
	rec := request(t, s, http.MethodGet, "/health", "", nil)
	if rec.Code != http.StatusOK {
		t.Fatalf("health = %d", rec.Code)
	}
}

func TestAuthRejected(t *testing.T) {
	s := newTestServer(t)
	if rec := request(t, s, http.MethodGet, "/episodes", "", nil); rec.Code != http.StatusUnauthorized {
		t.Fatalf("no key = %d, want 401", rec.Code)
	}
	if rec := request(t, s, http.MethodGet, "/episodes", "wrong", nil); rec.Code != http.StatusUnauthorized {
		t.Fatalf("wrong key = %d, want 401", rec.Code)
	}
	if rec := request(t, s, http.MethodGet, "/episodes", testKey, nil); rec.Code != http.StatusOK {
		t.Fatalf("valid key = %d, want 200", rec.Code)
	}
}

func TestAuthBearer(t *testing.T) {
	s := newTestServer(t)
	req := httptest.NewRequest(http.MethodGet, "/episodes", nil)
	req.Header.Set("Authorization", "Bearer "+testKey)
	rec := httptest.NewRecorder()
	s.ServeHTTP(rec, req)
	if rec.Code != http.StatusOK {
		t.Fatalf("bearer = %d, want 200", rec.Code)
	}
}

func TestStepUpsertCreateAndUpdate(t *testing.T) {
	s := newTestServer(t)
	report := stepReport{
		Step: "ftp_upload", Status: "in_progress",
		Metadata: Metadata{EpisodeNumber: "259", Title: "Testfolge", ReleaseDate: "2026-11-05", Profile: "studio"},
	}
	rec := request(t, s, http.MethodPost, "/episodes/259/steps", testKey, report)
	if rec.Code != http.StatusOK {
		t.Fatalf("create = %d: %s", rec.Code, rec.Body)
	}
	var ep Episode
	_ = json.Unmarshal(rec.Body.Bytes(), &ep)
	if len(ep.Steps) != 1 || ep.Steps[0].Status != "in_progress" {
		t.Fatalf("steps = %+v", ep.Steps)
	}

	report.Status = "done"
	rec = request(t, s, http.MethodPost, "/episodes/259/steps", testKey, report)
	_ = json.Unmarshal(rec.Body.Bytes(), &ep)
	if len(ep.Steps) != 1 || ep.Steps[0].Status != "done" {
		t.Fatalf("after update steps = %+v", ep.Steps)
	}
}

func TestStepInvalidStatus(t *testing.T) {
	s := newTestServer(t)
	report := stepReport{Step: "s3", Status: "exploded", Metadata: Metadata{EpisodeNumber: "1"}}
	if rec := request(t, s, http.MethodPost, "/episodes/1/steps", testKey, report); rec.Code != http.StatusBadRequest {
		t.Fatalf("invalid status = %d, want 400", rec.Code)
	}
	report = stepReport{Step: "", Status: "done", Metadata: Metadata{EpisodeNumber: "1"}}
	if rec := request(t, s, http.MethodPost, "/episodes/1/steps", testKey, report); rec.Code != http.StatusBadRequest {
		t.Fatalf("empty step = %d, want 400", rec.Code)
	}
}

func TestSlugToNumberPromotion(t *testing.T) {
	s := newTestServer(t)
	// First report: slug only (no number assigned yet).
	report := stepReport{Step: "transcribe", Status: "done", Metadata: Metadata{Slug: "mein-marathon"}}
	if rec := request(t, s, http.MethodPost, "/episodes/mein-marathon/steps", testKey, report); rec.Code != http.StatusOK {
		t.Fatalf("slug create = %d", rec.Code)
	}
	// Second report: number assigned, same slug.
	report = stepReport{Step: "ftp_upload", Status: "done", Metadata: Metadata{EpisodeNumber: "260", Slug: "mein-marathon"}}
	rec := request(t, s, http.MethodPost, "/episodes/260/steps", testKey, report)
	if rec.Code != http.StatusOK {
		t.Fatalf("promote = %d: %s", rec.Code, rec.Body)
	}
	var ep Episode
	_ = json.Unmarshal(rec.Body.Bytes(), &ep)
	if ep.ID != "260" || len(ep.Steps) != 2 {
		t.Fatalf("promotion lost steps: id=%s steps=%+v", ep.ID, ep.Steps)
	}
	// Old slug record must be gone.
	if rec := request(t, s, http.MethodGet, "/episodes/mein-marathon", testKey, nil); rec.Code != http.StatusNotFound {
		t.Fatalf("old slug record still present = %d", rec.Code)
	}
}

func TestListAndGetNotFound(t *testing.T) {
	s := newTestServer(t)
	if rec := request(t, s, http.MethodGet, "/episodes/999", testKey, nil); rec.Code != http.StatusNotFound {
		t.Fatalf("missing = %d, want 404", rec.Code)
	}
	for _, n := range []string{"1", "2"} {
		report := stepReport{Step: "s3", Status: "done", Metadata: Metadata{EpisodeNumber: n}}
		request(t, s, http.MethodPost, "/episodes/"+n+"/steps", testKey, report)
	}
	rec := request(t, s, http.MethodGet, "/episodes", testKey, nil)
	var eps []Episode
	_ = json.Unmarshal(rec.Body.Bytes(), &eps)
	if len(eps) != 2 {
		t.Fatalf("list len = %d", len(eps))
	}
	if eps[0].EpisodeNumber != "2" {
		t.Fatalf("list not sorted desc: %+v", eps)
	}
}

func TestSharedViewConsistency(t *testing.T) {
	s := newTestServer(t)
	report := stepReport{Step: "wordpress", Status: "failed", Metadata: Metadata{EpisodeNumber: "42"}}
	request(t, s, http.MethodPost, "/episodes/42/steps", testKey, report)

	read := func() Episode {
		rec := request(t, s, http.MethodGet, "/episodes/42", testKey, nil)
		var ep Episode
		_ = json.Unmarshal(rec.Body.Bytes(), &ep)
		return ep
	}
	a, b := read(), read()
	ja, _ := json.Marshal(a)
	jb, _ := json.Marshal(b)
	if !bytes.Equal(ja, jb) {
		t.Fatalf("two reads differ: %s vs %s", ja, jb)
	}
	if a.Steps[0].Status != "failed" {
		t.Fatalf("status = %s", a.Steps[0].Status)
	}
}

func TestContentStoreAndFetch(t *testing.T) {
	s := newTestServer(t)
	report := stepReport{Step: "transcribe", Status: "done", Metadata: Metadata{EpisodeNumber: "7"}}
	request(t, s, http.MethodPost, "/episodes/7/steps", testKey, report)

	body := contentReport{Key: "shownotes", Body: "# Folge 7"}
	if rec := request(t, s, http.MethodPost, "/episodes/7/content", testKey, body); rec.Code != http.StatusOK {
		t.Fatalf("content = %d", rec.Code)
	}
	rec := request(t, s, http.MethodGet, "/episodes/7", testKey, nil)
	var ep Episode
	_ = json.Unmarshal(rec.Body.Bytes(), &ep)
	if ep.Content["shownotes"] != "# Folge 7" {
		t.Fatalf("content = %+v", ep.Content)
	}
	// Content on unknown episode → 404.
	if rec := request(t, s, http.MethodPost, "/episodes/nope/content", testKey, body); rec.Code != http.StatusNotFound {
		t.Fatalf("content unknown ep = %d", rec.Code)
	}
}

func TestMetadataUpsertProfile(t *testing.T) {
	s := newTestServer(t)
	meta := Metadata{EpisodeNumber: "300", Title: "Video Folge", Profile: "video"}
	rec := request(t, s, http.MethodPost, "/episodes/300/metadata", testKey, meta)
	if rec.Code != http.StatusOK {
		t.Fatalf("metadata = %d", rec.Code)
	}
	var ep Episode
	_ = json.Unmarshal(rec.Body.Bytes(), &ep)
	if ep.Profile != "video" || ep.Title != "Video Folge" {
		t.Fatalf("ep = %+v", ep)
	}
}
