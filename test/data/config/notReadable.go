package testData

import (
	"errors"
	config "podflow/internal/configuration"
)

type NotReadableConfigurationFile struct {}

func (file NotReadableConfigurationFile) Read(path string) (config.Configuration, error) {
    return config.Configuration{}, errors.New("Not readable")
}

func (file NotReadableConfigurationFile) Path() (string, error) {
    return "~/unit-tests/config.yaml", nil
}
func (file NotReadableConfigurationFile) Write(config config.Configuration) error {
    return nil
}

func (file NotReadableConfigurationFile) IsNotExist(path string) bool {
    return false
}
