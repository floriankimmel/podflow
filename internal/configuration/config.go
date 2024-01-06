package config

import (
	"os"
	"path/filepath"
	"strings"

	"gopkg.in/yaml.v3"
)

const DEFAULT_XDG_CONFIG_DIRNAME = ".config"
const DEFAULT_CONFIG_DIRNAME = "podflow"

type File struct {
    Name                string `yaml:"name"`
    FileName            string `yaml:"fileName"`
    Required            bool `yaml:"required"`
    NotEmpty            bool `yaml:"notEmpty"`
    UmlauteNotAllowed      bool `yaml:"umlauteNotAllowed"`
}
 
type Configuration struct {
    CurrentEpisode int `yaml:"currentEpisode"`
    ReleaseDay string `yaml:"releaseDay"`
    ReleaseTime string `yaml:"releaseTime"`
    Files       []File `yaml:"files"`
}

func Load() (Configuration, error) {
    configFilePath, err := getConfigPath()

    if err != nil {
        return Configuration{}, err
    }

    if _, err := os.Stat(configFilePath); os.IsNotExist(err) {
		return Configuration{}, err

    }
    config, err := parse(configFilePath)
    if err != nil {
		return Configuration{}, err
    }

    dir, _ := os.Getwd()
    folder := filepath.Base(dir)

    for i := range config.Files {
        config.Files[i].FileName = strings.Replace(config.Files[i].FileName, "{{folderName}}", folder, -1)
    }

    return config, nil
}

func parse(configFilePath string) (Configuration, error) {
    data, err := os.ReadFile(configFilePath)
    if err != nil {
        return Configuration{}, err
    }
    
    var configuration Configuration

    if err := yaml.Unmarshal(data, &configuration); err != nil {
        return Configuration{}, err
    }

    return configuration, nil

}

func write(configuration Configuration) error {
    configFilePath, err := getConfigPath()

    if err != nil {
        return err
    }
    data, err := yaml.Marshal(configuration)

    if err != nil {
        return err
    }

    err = os.WriteFile(configFilePath, data, 0644)

    if err != nil {
        return err
    }

    return nil
}

func getConfigPath() (string, error) {
    homeDir, err := os.UserHomeDir()
    configFilePath := filepath.Join(homeDir, DEFAULT_XDG_CONFIG_DIRNAME, DEFAULT_CONFIG_DIRNAME, "config.yml")

	if err != nil {
		return "", err
	}
    return configFilePath, nil

}
