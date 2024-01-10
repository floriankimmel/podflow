package config

import (
	"os"
	"path/filepath"
	"strconv"
	"strings"
)

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

type StepFile struct {
    Source              string      `yaml:"source"`
    Target              string      `yaml:"target"`
}

type Step struct {
    FTP                 FTP         `yaml:"ftp"`
    Download            FTP         `yaml:"download"`
    Files               []StepFile  `yaml:"files"`
}
 
type Configuration struct {
    CurrentEpisode      int         `yaml:"currentEpisode"`
    ReleaseDay          string      `yaml:"releaseDay"`
    ReleaseTime         string      `yaml:"releaseTime"`
    Files               []File      `yaml:"files"`
    Steps               []Step      `yaml:"steps"`
}

func Load(io ConfigurationReaderWriter) (Configuration, error) {
    configFilePath, err := io.Path()

    if err != nil {
        return Configuration{}, err
    }

    if io.IsNotExist(configFilePath) {
		return Configuration{}, os.ErrNotExist

    }
    config, err := io.Read(configFilePath)
    if err != nil {
        return Configuration{}, err
    }

    return config, nil
}

func LoadAndReplacePlaceholders(io ConfigurationReaderWriter, dir string) (Configuration, error) {
    config, err := Load(io)

    if err != nil {
        return Configuration{}, err
    }
    return ReplacePlaceholders(config, dir), nil
}

func ReplacePlaceholders(config Configuration, dir string) Configuration {
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

