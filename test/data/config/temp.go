package testData

import (
	"os"
	"path/filepath"
	config "podflow/internal/configuration"

	"gopkg.in/yaml.v3"
)

type TempConfigurationFile struct {
    config.ConfigurationFile
}

func (file TempConfigurationFile) Path() (string, error) {
    return filepath.Join(os.TempDir(), "podflow", "podflow.yml"), nil
}

func (file TempConfigurationFile) Write(config config.Configuration) error {
    path, err := file.Path()

    if err != nil {
        return err
    }

    data, err := yaml.Marshal(config)

    if err != nil {
        return err
    }

    err = os.WriteFile(path, data, 0644)

    if err != nil {
        return err
    }

    return nil
}
