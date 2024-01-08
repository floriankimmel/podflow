package config

import (
	"os"
	"path/filepath"
	"strconv"
	"strings"

	"gopkg.in/yaml.v3"
)

const DEFAULT_XDG_CONFIG_DIRNAME = ".config"
const DEFAULT_CONFIG_DIRNAME = "podflow"

type File struct {
    Name                string      `yaml:"name"`
    FileName            string      `yaml:"fileName"`
    Required            bool        `yaml:"required"`
    NotEmpty            bool        `yaml:"notEmpty"`
    UmlauteNotAllowed   bool        `yaml:"umlauteNotAllowed"`
}

type FTP struct {
    Host                string      `yaml:"host"`
    Port                string      `yaml:"port"`
    Username            string      `yaml:"username"`
    Password            string      `yaml:"password"`
}

type Target struct {
    FTP                 FTP         `yaml:"ftp"`
}

type FileUpload struct {
    Source              string      `yaml:"source"`
    Target              string      `yaml:"target"`
}

type Step struct {
    Name                string      `yaml:"name"`
    Target              Target      `yaml:"target"`
    Files               []FileUpload`yaml:"files"`
}
 
type Configuration struct {
    CurrentEpisode      int         `yaml:"currentEpisode"`
    ReleaseDay          string      `yaml:"releaseDay"`
    ReleaseTime         string      `yaml:"releaseTime"`
    Files               []File      `yaml:"files"`
    Steps               []Step      `yaml:"steps"`
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

    return config, nil
}

func LoadAndReplacePlaceholders() (Configuration, error) {
    config, err := Load()
    if err != nil {
        return Configuration{}, err
    }
    return replacePlaceholders(config), nil
}

func replacePlaceholders(config Configuration) Configuration {
    dir, _ := os.Getwd()
    folder := filepath.Base(dir)

    for i := range config.Files {
        config.Files[i].FileName = strings.Replace(config.Files[i].FileName, "{{folderName}}", folder, -1)
    }

    for i := range config.Steps {
        step := config.Steps[i]
        for j := range config.Steps[i].Files {
            episodeNumberAsString := strconv.Itoa(config.CurrentEpisode)
            step.Files[j].Source = strings.Replace(step.Files[j].Source, "{{folderName}}", folder, -1)
            step.Files[j].Target = strings.Replace(step.Files[j].Target, "{{folderName}}", folder, -1)
            step.Files[j].Source = strings.Replace(step.Files[j].Source, "{{episodeNumber}}", episodeNumberAsString, -1)
            step.Files[j].Target = strings.Replace(step.Files[j].Target, "{{episodeNumber}}", episodeNumberAsString, -1)
        }  
    }
    return config
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
