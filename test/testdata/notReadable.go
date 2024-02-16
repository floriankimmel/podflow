package testdata

import (
	"errors"
	config "podflow/internal/configuration"
)

type NotReadableConfigurationFile struct {
	ValidConfigurationFile
}

func (file NotReadableConfigurationFile) Read(path string) (config.Configuration, error) {
	return config.Configuration{}, errors.New("Not readable")
}
