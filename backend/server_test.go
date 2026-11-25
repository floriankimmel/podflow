package main

import (
	"bytes"
	"database/sql"
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

func TestPathNumberIsIdentity(t *testing.T) {
	s := newTestServer(t)
	report := stepReport{Step: "transcript", Status: "done", Metadata: Metadata{EpisodeNumber: "999", Title: "Mein Marathon"}}
	rec := request(t, s, http.MethodPost, "/episodes/260/steps", testKey, report)
	if rec.Code != http.StatusOK {
		t.Fatalf("report = %d: %s", rec.Code, rec.Body)
	}
	var ep Episode
	_ = json.Unmarshal(rec.Body.Bytes(), &ep)
	if ep.EpisodeNumber != "260" || ep.ID != "260" || ep.Title != "Mein Marathon" {
		t.Fatalf("ep = %+v", ep)
	}
	if rec := request(t, s, http.MethodGet, "/episodes/999", testKey, nil); rec.Code != http.StatusNotFound {
		t.Fatalf("body number created an episode = %d", rec.Code)
	}
}

func TestMigrateFromSlugIdentity(t *testing.T) {
	path := filepath.Join(t.TempDir(), "legacy.db")
	db, err := sql.Open("sqlite", path)
	if err != nil {
		t.Fatal(err)
	}
	for _, stmt := range []string{
		`CREATE TABLE episodes (id TEXT PRIMARY KEY, episode_number TEXT NOT NULL DEFAULT '', slug TEXT NOT NULL DEFAULT '',
			title TEXT NOT NULL DEFAULT '', release_date TEXT NOT NULL DEFAULT '', profile TEXT NOT NULL DEFAULT '', updated_at TEXT NOT NULL)`,
		`CREATE TABLE steps (episode_id TEXT NOT NULL, step TEXT NOT NULL, status TEXT NOT NULL, updated_at TEXT NOT NULL,
			PRIMARY KEY (episode_id, step), FOREIGN KEY (episode_id) REFERENCES episodes(id) ON DELETE CASCADE)`,
		`CREATE TABLE content (episode_id TEXT NOT NULL, key TEXT NOT NULL, body TEXT NOT NULL, updated_at TEXT NOT NULL,
			PRIMARY KEY (episode_id, key), FOREIGN KEY (episode_id) REFERENCES episodes(id) ON DELETE CASCADE)`,
		`INSERT INTO episodes VALUES ('260', '260', 'mein-marathon', 'Mein Marathon', '', 'video', 't')`,
		`INSERT INTO episodes VALUES ('ohne-nummer', '', 'ohne-nummer', '', '', '', 't')`,
		`INSERT INTO steps VALUES ('260', 'transcript', 'done', 't')`,
		`INSERT INTO steps VALUES ('ohne-nummer', 'transcript', 'done', 't')`,
		`INSERT INTO content VALUES ('260', 'shownotes', '# 260', 't')`,
	} {
		if _, err := db.Exec(stmt); err != nil {
			t.Fatalf("%s: %v", stmt, err)
		}
	}
	_ = db.Close()

	store, err := NewStore(path)
	if err != nil {
		t.Fatalf("migrate: %v", err)
	}
	t.Cleanup(func() { _ = store.Close() })
	eps, err := store.List()
	if err != nil || len(eps) != 1 {
		t.Fatalf("list = %+v, %v", eps, err)
	}
	ep, err := store.Get("260")
	if err != nil {
		t.Fatal(err)
	}
	if ep.Title != "Mein Marathon" || ep.Profile != "video" || len(ep.Steps) != 1 {
		t.Fatalf("migrated ep = %+v", ep)
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

func TestContentRouteIsGone(t *testing.T) {
	s := newTestServer(t)
	report := stepReport{Step: "transcribe", Status: "done", Metadata: Metadata{EpisodeNumber: "7"}}
	request(t, s, http.MethodPost, "/episodes/7/steps", testKey, report)
	body := map[string]string{"key": "shownotes", "body": "# Folge 7"}
	if rec := request(t, s, http.MethodPost, "/episodes/7/content", testKey, body); rec.Code != http.StatusNotFound {
		t.Fatalf("content = %d, want 404", rec.Code)
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

func TestDeleteEpisode(t *testing.T) {
	s := newTestServer(t)
	for _, n := range []string{"1", "2"} {
		report := stepReport{Step: "auphonic_wait", Status: "done", Metadata: Metadata{EpisodeNumber: n}}
		request(t, s, http.MethodPost, "/episodes/"+n+"/steps", testKey, report)
	}

	if rec := request(t, s, http.MethodDelete, "/episodes/1", "", nil); rec.Code != http.StatusUnauthorized {
		t.Fatalf("delete without key = %d, want 401", rec.Code)
	}
	if rec := request(t, s, http.MethodDelete, "/episodes/1", testKey, nil); rec.Code != http.StatusOK {
		t.Fatalf("delete = %d, want 200", rec.Code)
	}
	if rec := request(t, s, http.MethodGet, "/episodes/1", testKey, nil); rec.Code != http.StatusNotFound {
		t.Fatalf("get after delete = %d, want 404", rec.Code)
	}
	if rec := request(t, s, http.MethodDelete, "/episodes/1", testKey, nil); rec.Code != http.StatusNotFound {
		t.Fatalf("second delete = %d, want 404", rec.Code)
	}

	rec := request(t, s, http.MethodGet, "/episodes", testKey, nil)
	var eps []Episode
	_ = json.Unmarshal(rec.Body.Bytes(), &eps)
	if len(eps) != 1 || eps[0].EpisodeNumber != "2" {
		t.Fatalf("list after delete = %+v", eps)
	}

	// A new report for the same number starts fresh: no old steps.
	report := stepReport{Step: "transcript", Status: "in_progress", Metadata: Metadata{EpisodeNumber: "1"}}
	request(t, s, http.MethodPost, "/episodes/1/steps", testKey, report)
	rec = request(t, s, http.MethodGet, "/episodes/1", testKey, nil)
	var ep Episode
	_ = json.Unmarshal(rec.Body.Bytes(), &ep)
	if len(ep.Steps) != 1 || ep.Steps[0].Step != "transcript" {
		t.Fatalf("recreated episode carries old data: %+v", ep)
	}
}
