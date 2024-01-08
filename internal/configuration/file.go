package config

import (
	"os"
	"path/filepath"

	yaml "gopkg.in/yaml.v3"
)

const DEFAULT_XDG_CONFIG_DIRNAME = ".config"
const DEFAULT_CONFIG_DIRNAME = "podflow"

type ConfigurationFile struct {
}

type ConfigurationReaderWriter interface {
    Read(path string)  (Configuration, error)
    Path()  (string, error)
    Write(config Configuration) error
    IsNotExist(path string) bool
}

func (file ConfigurationFile) IsNotExist(path string) bool {
    _, err := os.Stat(path)
    return os.IsNotExist(err)
}

func (file ConfigurationFile) Read(path string) (Configuration, error) {
    data, err := os.ReadFile(path)
    if err != nil {
        return Configuration{}, err
    }
    config := Configuration{}
    
    if err := yaml.Unmarshal(data, &config); err != nil {
        return Configuration{}, err
    }

    return config, nil
}

func (file ConfigurationFile) Write(config Configuration) error {
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

func (io ConfigurationFile) Path() (string, error) {
    homeDir, err := os.UserHomeDir()
    configFilePath := filepath.Join(homeDir, DEFAULT_XDG_CONFIG_DIRNAME, DEFAULT_CONFIG_DIRNAME, "config.yml")

	if err != nil {
		return "", err
	}
    return configFilePath, nil

}
