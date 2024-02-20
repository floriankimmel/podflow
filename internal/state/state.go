package state

import (
	"os"
	"path/filepath"
	config "podflow/internal/configuration"

	"gopkg.in/yaml.v3"
)

type Metadata struct {
	EpisodeNumber int    `yaml:"episodeNumber"`
	ReleaseDate   string `yaml:"releaseDate"`
	Title         string `yaml:"title"`
}
type State struct {
	Metadata             Metadata      `yaml:"metadata"`
	FTPUploaded          bool          `yaml:"ftpUploaded"`
	S3Uploaded           bool          `yaml:"s3Uploaded"`
	AuphonicProduction   bool          `yaml:"auphonicProduction"`
	WordpressBlogCreated bool          `yaml:"wordpressBlogCreated"`
	Downloaded           bool          `yaml:"downloaded"`
	ChapterMarks         []ChapterMark `yaml:"chapterMarks"`
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
