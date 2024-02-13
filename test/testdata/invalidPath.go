package testdata

import (
	"errors"
)

type InvalidPathConfigurationFile struct {
	ValidConfigurationFile
}

func (file InvalidPathConfigurationFile) Path() (string, error) {
	return "", errors.New("Invalid path")
}
