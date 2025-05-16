package state

import (
	"encoding/json"
	"os"
	"path/filepath"
	config "podflow/internal/configuration"

	"gopkg.in/yaml.v3"
)

type Metadata struct {
	EpisodeNumber string `yaml:"episodeNumber,omitempty"`
	ReleaseDate   string `yaml:"releaseDate,omitempty"`
	Title         string `yaml:"title,omitempty"`
}
type State struct {
	Metadata             Metadata      `yaml:"metadata,omitempty"`
	Wordpress            Wordpress     `yaml:"wordpress,omitempty"`
	FTPUploaded          bool          `yaml:"ftpUploaded,omitempty"`
	S3Uploaded           bool          `yaml:"s3Uploaded,omitempty"`
	AuphonicProduction   bool          `yaml:"auphonicProduction,omitempty"`
	WordpressBlogCreated bool          `yaml:"wordpressBlogCreated,omitempty"`
	SteadyHqCreated      bool          `yaml:"steadyHqCreated,omitempty"`
	Downloaded           bool          `yaml:"downloaded,omitempty"`
	ChapterMarks         []ChapterMark `yaml:"chapterMarks,omitempty"`
}
type Wordpress struct {
	WordpressID     string      `yaml:"wordpressID,omitempty"`
	PodloveID       json.Number `yaml:"podloveID,omitempty"`
	FeaturedMediaID string      `yaml:"featuredMediaID,omitempty"`
}

type StateReaderWriter interface {
	Read() (State, error)
	Write(config State) error
	GetStateFilePath() string
}

type StateFile struct{}

func (file StateFile) Read() (State, error) {
	stateFilePath := file.GetStateFilePath()

	if err := createIfNotExists(stateFilePath); err != nil {
		return State{}, err
	}

	data, err := os.ReadFile(stateFilePath)

	if err != nil {
		return State{}, err
	}

	config := State{}

	if err := yaml.Unmarshal(data, &config); err != nil {
		return State{}, err
	}

	return config, nil
}

func (file StateFile) Write(state State) error {
	stateFilePath := file.GetStateFilePath()

	if err := createIfNotExists(stateFilePath); err != nil {
		return err
	}

	data, err := yaml.Marshal(state)

	if err != nil {
		return err
	}

	err = os.WriteFile(stateFilePath, data, 0600)

	if err != nil {
		return err
	}

	return nil
}

func createIfNotExists(stateFilePath string) error {
	if _, err := os.Stat(stateFilePath); os.IsNotExist(err) {
		file, err := os.Create(stateFilePath)
		if err != nil {
			return err
		}
		defer file.Close()
	}
	return nil
}
func (file StateFile) GetStateFilePath() string {
	path := config.Dir()
	return filepath.Join(path, filepath.Base(path)+".state.yml")
}
