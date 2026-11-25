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
	// ID repeats the episode number for clients that still read "id"
	// (desktop 1.3.0 and older).
	ID            string            `json:"id"`
	EpisodeNumber string            `json:"episodeNumber"`
	Title         string            `json:"title,omitempty"`
	ReleaseDate   string            `json:"releaseDate,omitempty"`
	Profile       string            `json:"profile,omitempty"`
	Steps         []StepStatus      `json:"steps"`
	Content       map[string]string `json:"content,omitempty"`
	UpdatedAt     string            `json:"updatedAt"`
}

type Metadata struct {
	EpisodeNumber string `json:"episodeNumber,omitempty"`
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

const schema = `
	CREATE TABLE IF NOT EXISTS episodes (
		episode_number TEXT PRIMARY KEY,
		title TEXT NOT NULL DEFAULT '',
		release_date TEXT NOT NULL DEFAULT '',
		profile TEXT NOT NULL DEFAULT '',
		updated_at TEXT NOT NULL
	);
	CREATE TABLE IF NOT EXISTS steps (
		episode_number TEXT NOT NULL,
		step TEXT NOT NULL,
		status TEXT NOT NULL,
		updated_at TEXT NOT NULL,
		PRIMARY KEY (episode_number, step),
		FOREIGN KEY (episode_number) REFERENCES episodes(episode_number) ON DELETE CASCADE
	);
	CREATE TABLE IF NOT EXISTS content (
		episode_number TEXT NOT NULL,
		key TEXT NOT NULL,
		body TEXT NOT NULL,
		updated_at TEXT NOT NULL,
		PRIMARY KEY (episode_number, key),
		FOREIGN KEY (episode_number) REFERENCES episodes(episode_number) ON DELETE CASCADE
	);
`

func (s *Store) migrate() error {
	legacy, err := s.hasColumn("episodes", "id")
	if err != nil {
		return err
	}
	if legacy {
		return s.migrateFromSlugIdentity()
	}
	_, err = s.db.Exec(schema)
	return err
}

func (s *Store) hasColumn(table, column string) (bool, error) {
	var n int
	err := s.db.QueryRow(
		`SELECT COUNT(*) FROM pragma_table_info(?) WHERE name = ?`, table, column,
	).Scan(&n)
	return n > 0, err
}

// migrateFromSlugIdentity converts the old schema, where an episode was keyed
// by its slug until it had a number, to one keyed by the episode number.
// Episodes that never got a number are dropped with their steps and content.
func (s *Store) migrateFromSlugIdentity() error {
	tx, err := s.db.Begin()
	if err != nil {
		return err
	}
	defer func() { _ = tx.Rollback() }()

	for _, stmt := range []string{
		`ALTER TABLE episodes RENAME TO episodes_old`,
		`ALTER TABLE steps RENAME TO steps_old`,
		`ALTER TABLE content RENAME TO content_old`,
		schema,
		`INSERT INTO episodes (episode_number, title, release_date, profile, updated_at)
			SELECT episode_number, title, release_date, profile, updated_at
			FROM episodes_old WHERE episode_number != ''`,
		`INSERT INTO steps (episode_number, step, status, updated_at)
			SELECT e.episode_number, st.step, st.status, st.updated_at
			FROM steps_old st JOIN episodes_old e ON e.id = st.episode_id
			WHERE e.episode_number != ''`,
		`INSERT INTO content (episode_number, key, body, updated_at)
			SELECT e.episode_number, c.key, c.body, c.updated_at
			FROM content_old c JOIN episodes_old e ON e.id = c.episode_id
			WHERE e.episode_number != ''`,
		`DROP TABLE content_old`,
		`DROP TABLE steps_old`,
		`DROP TABLE episodes_old`,
	} {
		if _, err := tx.Exec(stmt); err != nil {
			return fmt.Errorf("migrate to episode number identity: %w", err)
		}
	}
	return tx.Commit()
}

func (s *Store) Close() error { return s.db.Close() }

// Delete removes an episode with its steps and content. SQLite does not
// enforce the ON DELETE CASCADE without a per-connection pragma, so the
// child rows are deleted explicitly.
func (s *Store) Delete(number string) error {
	tx, err := s.db.Begin()
	if err != nil {
		return err
	}
	defer func() { _ = tx.Rollback() }()

	if _, err := tx.Exec(`DELETE FROM steps WHERE episode_number = ?`, number); err != nil {
		return err
	}
	if _, err := tx.Exec(`DELETE FROM content WHERE episode_number = ?`, number); err != nil {
		return err
	}
	res, err := tx.Exec(`DELETE FROM episodes WHERE episode_number = ?`, number)
	if err != nil {
		return err
	}
	if n, _ := res.RowsAffected(); n == 0 {
		return ErrNotFound
	}
	return tx.Commit()
}

func now() string { return time.Now().UTC().Format(time.RFC3339) }

var errNumberRequired = errors.New("episode number required")

const upsertEpisode = `
	INSERT INTO episodes (episode_number, title, release_date, profile, updated_at)
	VALUES (?, ?, ?, ?, ?)
	ON CONFLICT(episode_number) DO UPDATE SET
		title        = CASE WHEN excluded.title        != '' THEN excluded.title        ELSE episodes.title        END,
		release_date = CASE WHEN excluded.release_date != '' THEN excluded.release_date ELSE episodes.release_date END,
		profile      = CASE WHEN excluded.profile      != '' THEN excluded.profile      ELSE episodes.profile      END,
		updated_at = excluded.updated_at
`

func (s *Store) upsertEpisode(meta Metadata, ts string) error {
	if meta.EpisodeNumber == "" {
		return errNumberRequired
	}
	_, err := s.db.Exec(upsertEpisode, meta.EpisodeNumber, meta.Title, meta.ReleaseDate, meta.Profile, ts)
	return err
}

// UpsertStep creates the episode on first report and records the step status.
func (s *Store) UpsertStep(meta Metadata, step, status string) (*Episode, error) {
	if !validStatuses[status] {
		return nil, fmt.Errorf("%w: %q", ErrInvalidStatus, status)
	}
	if step == "" {
		return nil, errors.New("step required")
	}
	ts := now()
	if err := s.upsertEpisode(meta, ts); err != nil {
		return nil, err
	}
	_, err := s.db.Exec(`
		INSERT INTO steps (episode_number, step, status, updated_at) VALUES (?, ?, ?, ?)
		ON CONFLICT(episode_number, step) DO UPDATE SET status = excluded.status, updated_at = excluded.updated_at
	`, meta.EpisodeNumber, step, status, ts)
	if err != nil {
		return nil, err
	}
	return s.Get(meta.EpisodeNumber)
}

// UpsertMetadata creates/updates an episode without touching steps.
func (s *Store) UpsertMetadata(meta Metadata) (*Episode, error) {
	ts := now()
	if err := s.upsertEpisode(meta, ts); err != nil {
		return nil, err
	}
	return s.Get(meta.EpisodeNumber)
}

// PutContent stores a named content artifact (transcript, shownotes, ...) for shared viewing.
func (s *Store) PutContent(number, key, body string) error {
	var exists string
	if err := s.db.QueryRow(`SELECT episode_number FROM episodes WHERE episode_number = ?`, number).Scan(&exists); err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return ErrNotFound
		}
		return err
	}
	ts := now()
	_, err := s.db.Exec(`
		INSERT INTO content (episode_number, key, body, updated_at) VALUES (?, ?, ?, ?)
		ON CONFLICT(episode_number, key) DO UPDATE SET body = excluded.body, updated_at = excluded.updated_at
	`, number, key, body, ts)
	if err != nil {
		return err
	}
	_, err = s.db.Exec(`UPDATE episodes SET updated_at = ? WHERE episode_number = ?`, ts, number)
	return err
}

func (s *Store) Get(number string) (*Episode, error) {
	ep := &Episode{ID: number, EpisodeNumber: number, Steps: []StepStatus{}, Content: map[string]string{}}
	err := s.db.QueryRow(
		`SELECT title, release_date, profile, updated_at FROM episodes WHERE episode_number = ?`, number,
	).Scan(&ep.Title, &ep.ReleaseDate, &ep.Profile, &ep.UpdatedAt)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, ErrNotFound
	}
	if err != nil {
		return nil, err
	}
	rows, err := s.db.Query(`SELECT step, status, updated_at FROM steps WHERE episode_number = ? ORDER BY step`, number)
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
	crows, err := s.db.Query(`SELECT key, body FROM content WHERE episode_number = ?`, number)
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
	rows, err := s.db.Query(`SELECT episode_number FROM episodes ORDER BY CAST(episode_number AS INTEGER) DESC, episode_number DESC`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var numbers []string
	for rows.Next() {
		var number string
		if err := rows.Scan(&number); err != nil {
			return nil, err
		}
		numbers = append(numbers, number)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	episodes := []*Episode{}
	for _, number := range numbers {
		ep, err := s.Get(number)
		if err != nil {
			return nil, err
		}
		// Keep list payload small: no content bodies in the list.
		ep.Content = nil
		episodes = append(episodes, ep)
	}
	return episodes, nil
}
