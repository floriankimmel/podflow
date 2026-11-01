package main

import (
	"database/sql"
	"errors"
	"fmt"
	"time"

	_ "modernc.org/sqlite"
)

// Valid step statuses.
var validStatuses = map[string]bool{
	"pending":     true,
	"in_progress": true,
	"done":        true,
	"failed":      true,
}

var ErrNotFound = errors.New("episode not found")
var ErrInvalidStatus = errors.New("invalid status")

type StepStatus struct {
	Step      string `json:"step"`
	Status    string `json:"status"`
	UpdatedAt string `json:"updatedAt"`
}

type Episode struct {
	ID            string            `json:"id"`
	EpisodeNumber string            `json:"episodeNumber,omitempty"`
	Slug          string            `json:"slug,omitempty"`
	Title         string            `json:"title,omitempty"`
	ReleaseDate   string            `json:"releaseDate,omitempty"`
	Profile       string            `json:"profile,omitempty"`
	Steps         []StepStatus      `json:"steps"`
	Content       map[string]string `json:"content,omitempty"`
	UpdatedAt     string            `json:"updatedAt"`
}

type Metadata struct {
	EpisodeNumber string `json:"episodeNumber,omitempty"`
	Slug          string `json:"slug,omitempty"`
	Title         string `json:"title,omitempty"`
	ReleaseDate   string `json:"releaseDate,omitempty"`
	Profile       string `json:"profile,omitempty"`
}

type Store struct {
	db *sql.DB
}

func NewStore(path string) (*Store, error) {
	db, err := sql.Open("sqlite", path)
	if err != nil {
		return nil, err
	}
	// Single fly machine, single writer: serialize access.
	db.SetMaxOpenConns(1)
	s := &Store{db: db}
	if err := s.migrate(); err != nil {
		return nil, err
	}
	return s, nil
}

func (s *Store) migrate() error {
	_, err := s.db.Exec(`
		CREATE TABLE IF NOT EXISTS episodes (
			id TEXT PRIMARY KEY,
			episode_number TEXT NOT NULL DEFAULT '',
			slug TEXT NOT NULL DEFAULT '',
			title TEXT NOT NULL DEFAULT '',
			release_date TEXT NOT NULL DEFAULT '',
			profile TEXT NOT NULL DEFAULT '',
			updated_at TEXT NOT NULL
		);
		CREATE TABLE IF NOT EXISTS steps (
			episode_id TEXT NOT NULL,
			step TEXT NOT NULL,
			status TEXT NOT NULL,
			updated_at TEXT NOT NULL,
			PRIMARY KEY (episode_id, step),
			FOREIGN KEY (episode_id) REFERENCES episodes(id) ON DELETE CASCADE
		);
		CREATE TABLE IF NOT EXISTS content (
			episode_id TEXT NOT NULL,
			key TEXT NOT NULL,
			body TEXT NOT NULL,
			updated_at TEXT NOT NULL,
			PRIMARY KEY (episode_id, key),
			FOREIGN KEY (episode_id) REFERENCES episodes(id) ON DELETE CASCADE
		);
	`)
	return err
}

func (s *Store) Close() error { return s.db.Close() }

func now() string { return time.Now().UTC().Format(time.RFC3339) }

// resolveID returns the canonical episode row id for an incoming identity.
// Identity is the episode number when present, otherwise the slug.
// A report carrying both a number and a slug promotes an existing slug-keyed
// row to the number (slug→number promotion, design D3).
func (s *Store) resolveID(meta Metadata) (string, error) {
	identity := meta.EpisodeNumber
	if identity == "" {
		identity = meta.Slug
	}
	if identity == "" {
		return "", errors.New("episode identity required (episodeNumber or slug)")
	}

	if meta.EpisodeNumber != "" && meta.Slug != "" {
		// Promote a pre-number record keyed by slug.
		var oldID string
		err := s.db.QueryRow(
			`SELECT id FROM episodes WHERE id = ? AND episode_number = ''`, meta.Slug,
		).Scan(&oldID)
		if err == nil && oldID != meta.EpisodeNumber {
			tx, err := s.db.Begin()
			if err != nil {
				return "", err
			}
			defer func() { _ = tx.Rollback() }()
			if _, err := tx.Exec(`UPDATE episodes SET id = ?, episode_number = ? WHERE id = ?`,
				meta.EpisodeNumber, meta.EpisodeNumber, oldID); err != nil {
				return "", err
			}
			if _, err := tx.Exec(`UPDATE steps SET episode_id = ? WHERE episode_id = ?`,
				meta.EpisodeNumber, oldID); err != nil {
				return "", err
			}
			if _, err := tx.Exec(`UPDATE content SET episode_id = ? WHERE episode_id = ?`,
				meta.EpisodeNumber, oldID); err != nil {
				return "", err
			}
			if err := tx.Commit(); err != nil {
				return "", err
			}
		}
	}
	return identity, nil
}

// UpsertStep creates the episode on first report and records the step status.
func (s *Store) UpsertStep(meta Metadata, step, status string) (*Episode, error) {
	if !validStatuses[status] {
		return nil, fmt.Errorf("%w: %q", ErrInvalidStatus, status)
	}
	if step == "" {
		return nil, errors.New("step required")
	}
	id, err := s.resolveID(meta)
	if err != nil {
		return nil, err
	}
	ts := now()
	_, err = s.db.Exec(`
		INSERT INTO episodes (id, episode_number, slug, title, release_date, profile, updated_at)
		VALUES (?, ?, ?, ?, ?, ?, ?)
		ON CONFLICT(id) DO UPDATE SET
			episode_number = CASE WHEN excluded.episode_number != '' THEN excluded.episode_number ELSE episodes.episode_number END,
			slug           = CASE WHEN excluded.slug           != '' THEN excluded.slug           ELSE episodes.slug           END,
			title          = CASE WHEN excluded.title          != '' THEN excluded.title          ELSE episodes.title          END,
			release_date   = CASE WHEN excluded.release_date   != '' THEN excluded.release_date   ELSE episodes.release_date   END,
			profile        = CASE WHEN excluded.profile        != '' THEN excluded.profile        ELSE episodes.profile        END,
			updated_at = excluded.updated_at
	`, id, meta.EpisodeNumber, meta.Slug, meta.Title, meta.ReleaseDate, meta.Profile, ts)
	if err != nil {
		return nil, err
	}
	_, err = s.db.Exec(`
		INSERT INTO steps (episode_id, step, status, updated_at) VALUES (?, ?, ?, ?)
		ON CONFLICT(episode_id, step) DO UPDATE SET status = excluded.status, updated_at = excluded.updated_at
	`, id, step, status, ts)
	if err != nil {
		return nil, err
	}
	return s.Get(id)
}

// UpsertMetadata creates/updates an episode without touching steps.
func (s *Store) UpsertMetadata(meta Metadata) (*Episode, error) {
	id, err := s.resolveID(meta)
	if err != nil {
		return nil, err
	}
	ts := now()
	_, err = s.db.Exec(`
		INSERT INTO episodes (id, episode_number, slug, title, release_date, profile, updated_at)
		VALUES (?, ?, ?, ?, ?, ?, ?)
		ON CONFLICT(id) DO UPDATE SET
			episode_number = CASE WHEN excluded.episode_number != '' THEN excluded.episode_number ELSE episodes.episode_number END,
			slug           = CASE WHEN excluded.slug           != '' THEN excluded.slug           ELSE episodes.slug           END,
			title          = CASE WHEN excluded.title          != '' THEN excluded.title          ELSE episodes.title          END,
			release_date   = CASE WHEN excluded.release_date   != '' THEN excluded.release_date   ELSE episodes.release_date   END,
			profile        = CASE WHEN excluded.profile        != '' THEN excluded.profile        ELSE episodes.profile        END,
			updated_at = excluded.updated_at
	`, id, meta.EpisodeNumber, meta.Slug, meta.Title, meta.ReleaseDate, meta.Profile, ts)
	if err != nil {
		return nil, err
	}
	return s.Get(id)
}

// PutContent stores a named content artifact (transcript, shownotes, ...) for shared viewing.
func (s *Store) PutContent(id, key, body string) error {
	var exists string
	if err := s.db.QueryRow(`SELECT id FROM episodes WHERE id = ?`, id).Scan(&exists); err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return ErrNotFound
		}
		return err
	}
	ts := now()
	_, err := s.db.Exec(`
		INSERT INTO content (episode_id, key, body, updated_at) VALUES (?, ?, ?, ?)
		ON CONFLICT(episode_id, key) DO UPDATE SET body = excluded.body, updated_at = excluded.updated_at
	`, id, key, body, ts)
	if err != nil {
		return err
	}
	_, err = s.db.Exec(`UPDATE episodes SET updated_at = ? WHERE id = ?`, ts, id)
	return err
}

func (s *Store) Get(id string) (*Episode, error) {
	ep := &Episode{ID: id, Steps: []StepStatus{}, Content: map[string]string{}}
	err := s.db.QueryRow(
		`SELECT episode_number, slug, title, release_date, profile, updated_at FROM episodes WHERE id = ?`, id,
	).Scan(&ep.EpisodeNumber, &ep.Slug, &ep.Title, &ep.ReleaseDate, &ep.Profile, &ep.UpdatedAt)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, ErrNotFound
	}
	if err != nil {
		return nil, err
	}
	rows, err := s.db.Query(`SELECT step, status, updated_at FROM steps WHERE episode_id = ? ORDER BY step`, id)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	for rows.Next() {
		var st StepStatus
		if err := rows.Scan(&st.Step, &st.Status, &st.UpdatedAt); err != nil {
			return nil, err
		}
		ep.Steps = append(ep.Steps, st)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	crows, err := s.db.Query(`SELECT key, body FROM content WHERE episode_id = ?`, id)
	if err != nil {
		return nil, err
	}
	defer crows.Close()
	for crows.Next() {
		var k, b string
		if err := crows.Scan(&k, &b); err != nil {
			return nil, err
		}
		ep.Content[k] = b
	}
	if err := crows.Err(); err != nil {
		return nil, err
	}
	return ep, nil
}

func (s *Store) List() ([]*Episode, error) {
	rows, err := s.db.Query(`SELECT id FROM episodes ORDER BY CAST(episode_number AS INTEGER) DESC, id DESC`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var ids []string
	for rows.Next() {
		var id string
		if err := rows.Scan(&id); err != nil {
			return nil, err
		}
		ids = append(ids, id)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	episodes := []*Episode{}
	for _, id := range ids {
		ep, err := s.Get(id)
		if err != nil {
			return nil, err
		}
		// Keep list payload small: no content bodies in the list.
		ep.Content = nil
		episodes = append(episodes, ep)
	}
	return episodes, nil
}
