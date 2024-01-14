package config

import (
	"os"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
)

type EpisodeFile struct {
    Name                string          `yaml:"name"`
    FileName            string          `yaml:"fileName"`
    Required            bool            `yaml:"required"`
    NotEmpty            bool            `yaml:"notEmpty"`
    UmlauteNotAllowed   bool            `yaml:"umlauteNotAllowed"`
}

type Auphonic struct {
    Username            string          `yaml:"username"`
    Password            string          `yaml:"password"`
    Preset              string          `yaml:"preset"`
    FileServer          string          `yaml:"fileServer"`
    Title               string          `yaml:"title"`
    Image               string          `yaml:"image"`
    Chapters            string          `yaml:"chapters"`
    Episode             string          `yaml:"episode"`

}

type FTP struct {
    Host                string          `yaml:"host"`
    Port                string          `yaml:"port"`
    Username            string          `yaml:"username"`
    Password            string          `yaml:"password"`
    Files               []FtpFile       `yaml:"files"`
}

type FtpFile struct {
    Source              string          `yaml:"source"`
    Target              string          `yaml:"target"`
}

type Step struct {
    FTP                 FTP             `yaml:"ftp"`
    Download            FTP             `yaml:"download"`
    Auphonic            Auphonic        `yaml:"auphonic"`
}
 
type Configuration struct {
    CurrentEpisode      int             `yaml:"currentEpisode"`
    ReleaseDay          string          `yaml:"releaseDay"`
    ReleaseTime         string          `yaml:"releaseTime"`
    Files               []EpisodeFile   `yaml:"files"`
    Steps               []Step          `yaml:"steps"`
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

func ReplaceEnvVariable(replaceString string) string {
    re := regexp.MustCompile("{{env.(.*?)}}")
	res := re.FindAllStringSubmatch(replaceString, -1)

	for _, match := range res {
		envVar := match[1]
		value := os.Getenv(envVar)
		replaceString = re.ReplaceAllString(replaceString, value)
	}
    return replaceString
}

func ReplacePlaceholders(config Configuration, dir string) Configuration {
    folder := filepath.Base(dir)

    for i := range config.Files {
        config.Files[i].FileName = strings.Replace(config.Files[i].FileName, "{{folderName}}", folder, -1)
    }

    for i := range config.Steps {
        step := config.Steps[i]
        episodeNumberAsString := strconv.Itoa(config.CurrentEpisode)
        for j := range config.Steps[i].FTP.Files {
            replaceString(&config.Steps[i].FTP.Files[j].Source, folder, episodeNumberAsString)
            replaceString(&config.Steps[i].FTP.Files[j].Target, folder, episodeNumberAsString)
        }  
        for j := range config.Steps[i].Download.Files {
            replaceString(&config.Steps[i].Download.Files[j].Source, folder, episodeNumberAsString)
            replaceString(&config.Steps[i].Download.Files[j].Target, folder, episodeNumberAsString)
        }  

        if step.Auphonic != (Auphonic{}) {
            replaceString(&config.Steps[i].Auphonic.Episode, folder, episodeNumberAsString)
            replaceString(&config.Steps[i].Auphonic.Image, folder, episodeNumberAsString)
            replaceString(&config.Steps[i].Auphonic.Chapters, folder, episodeNumberAsString)
        }
    }
    return config
}

func replaceString(replaceString *string, folder string, episodeNumberAsString string) {
    *replaceString = strings.Replace(*replaceString, "{{folderName}}", folder, -1)
    *replaceString = strings.Replace(*replaceString, "{{episodeNumber}}", episodeNumberAsString, -1)
}


