package testData

import (
	"errors"
	config "podflow/internal/configuration"
)

type InvalidPathConfigurationFile struct {}

func (file InvalidPathConfigurationFile) Read(path string) (config.Configuration, error) {
    return config.Configuration{}, nil
}

func (file InvalidPathConfigurationFile) Path() (string, error) {
    return "", errors.New("Invalid path")
}
func (file InvalidPathConfigurationFile) Write(config config.Configuration) error {
    return nil
}

func (file InvalidPathConfigurationFile) IsNotExist(path string) bool {
    return false
}
