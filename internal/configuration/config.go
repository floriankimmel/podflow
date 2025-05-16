package config

import (
	"os"
	"path/filepath"
	"regexp"
	"strings"
)

type EpisodeFile struct {
	Name              string `yaml:"name,omitempty"`
	FileName          string `yaml:"fileName,omitempty"`
	Required          bool   `yaml:"required,omitempty"`
	NotEmpty          bool   `yaml:"notEmpty,omitempty"`
	UmlauteNotAllowed bool   `yaml:"umlauteNotAllowed,omitempty"`
}

type AuphonicFiles struct {
	Image    string `yaml:"image,omitempty"`
	Chapters string `yaml:"chapters,omitempty"`
	Episode  string `yaml:"episode,omitempty"`
}

type Auphonic struct {
	Username   string          `yaml:"username,omitempty"`
	Password   string          `yaml:"password,omitempty"`
	Preset     string          `yaml:"preset,omitempty"`
	FileServer string          `yaml:"fileServer,omitempty"`
	Title      string          `yaml:"title,omitempty"`
	Files      []AuphonicFiles `yaml:"files,omitempty"`
}

type S3Bucket struct {
	Region string    `yaml:"region,omitempty"`
	Name   string    `yaml:"name,omitempty"`
	Files  []FtpFile `yaml:"files,omitempty"`
}

type S3 struct {
	Buckets []S3Bucket `yaml:"buckets,omitempty"`
}

type FTP struct {
	Host     string    `yaml:"host,omitempty"`
	Port     string    `yaml:"port,omitempty"`
	Username string    `yaml:"username,omitempty"`
	Password string    `yaml:"password,omitempty"`
	Files    []FtpFile `yaml:"files,omitempty"`
}

type FtpFile struct {
	Source string `yaml:"source,omitempty"`
	Target string `yaml:"target,omitempty"`
}

type Wordpress struct {
	APIKey    string `yaml:"apiKey,omitempty"`
	Server    string `yaml:"server,omitempty"`
	Image     string `yaml:"image,omitempty"`
	Poster    string `yaml:"poster,omitempty"`
	Episode   string `yaml:"episode,omitempty"`
	ShowNotes string `yaml:"showNotes,omitempty"`
	Chapter   string `yaml:"chapter,omitempty"`
}

type SteadyHq struct {
	APIKey    string `yaml:"apiKey,omitempty"`
	Image     string `yaml:"image,omitempty"`
	Episode   string `yaml:"episode,omitempty"`
	Title     string `yaml:"title,omitempty"`
	ShowNotes string `yaml:"showNotes,omitempty"`
}

type Step struct {
	FTP       FTP       `yaml:"ftp,omitempty"`
	Download  FTP       `yaml:"download,omitempty"`
	S3        S3        `yaml:"s3,omitempty"`
	Auphonic  Auphonic  `yaml:"auphonic,omitempty"`
	Wordpress Wordpress `yaml:"wordpress,omitempty"`
	SteadyHq  SteadyHq  `yaml:"steadyhq,omitempty"`
}

type Configuration struct {
	CurrentEpisode string        `yaml:"currentEpisode,omitempty"`
	ReleaseDay     string        `yaml:"releaseDay,omitempty"`
	ReleaseTime    string        `yaml:"releaseTime,omitempty"`
	Files          []EpisodeFile `yaml:"files,omitempty"`
	Steps          []Step        `yaml:"steps,omitempty"`
}

func Load(io ConfigurationReaderWriter) (Configuration, error) {
	configFilePath, err := io.Path()

	if err != nil {
		return Configuration{}, err
	}

	if io.DoesNotExist(configFilePath) {
		return Configuration{}, os.ErrNotExist

	}
	config, err := io.Read(configFilePath)
	if err != nil {
		return Configuration{}, err
	}

	return config, nil
}

type ReplacementValues struct {
	EpisodeNumber string
	FolderName    string
}

func LoadAndReplacePlaceholders(io ConfigurationReaderWriter, dir string) (Configuration, error) {
	config, err := Load(io)

	if err != nil {
		return Configuration{}, err
	}
	replacementValues := ReplacementValues{
		EpisodeNumber: config.CurrentEpisode,
		FolderName:    filepath.Base(dir),
	}
	return ReplacePlaceholders(config, replacementValues), nil

}

func ReplacePlaceholders(config Configuration, replacementValues ReplacementValues) Configuration {
	for i := range config.Files {
		replace(&config.Files[i].FileName, replacementValues)
		replace(&config.Files[i].Name, replacementValues)
	}

	for i := range config.Steps {
		if len(config.Steps[i].FTP.Files) > 0 {
			replace(&config.Steps[i].FTP.Username, replacementValues)
			replace(&config.Steps[i].FTP.Password, replacementValues)

			for j := range config.Steps[i].FTP.Files {
				replace(&config.Steps[i].FTP.Files[j].Source, replacementValues)
				replace(&config.Steps[i].FTP.Files[j].Target, replacementValues)
			}
		}

		if len(config.Steps[i].Download.Files) > 0 {
			replace(&config.Steps[i].Download.Username, replacementValues)
			replace(&config.Steps[i].Download.Password, replacementValues)

			for j := range config.Steps[i].Download.Files {
				replace(&config.Steps[i].Download.Files[j].Source, replacementValues)
				replace(&config.Steps[i].Download.Files[j].Target, replacementValues)
			}
		}
		for j := range config.Steps[i].S3.Buckets {
			for k := range config.Steps[i].S3.Buckets[j].Files {
				replace(&config.Steps[i].S3.Buckets[j].Files[k].Source, replacementValues)
				replace(&config.Steps[i].S3.Buckets[j].Files[k].Target, replacementValues)
			}
		}

		if config.Steps[i].Wordpress != (Wordpress{}) {
			replace(&config.Steps[i].Wordpress.Episode, replacementValues)
			replace(&config.Steps[i].Wordpress.Chapter, replacementValues)
			replace(&config.Steps[i].Wordpress.Image, replacementValues)
			replace(&config.Steps[i].Wordpress.Poster, replacementValues)
			replace(&config.Steps[i].Wordpress.ShowNotes, replacementValues)
			replace(&config.Steps[i].Wordpress.APIKey, replacementValues)
		}

		if SteadyHq(config.Steps[i].SteadyHq) != (SteadyHq{}) {
			replace(&config.Steps[i].SteadyHq.Episode, replacementValues)
			replace(&config.Steps[i].SteadyHq.Title, replacementValues)
			replace(&config.Steps[i].SteadyHq.Image, replacementValues)
			replace(&config.Steps[i].SteadyHq.ShowNotes, replacementValues)
			replace(&config.Steps[i].SteadyHq.APIKey, replacementValues)
		}

		if len(config.Steps[i].Auphonic.Files) > 0 {
			replace(&config.Steps[i].Auphonic.Username, replacementValues)
			replace(&config.Steps[i].Auphonic.Password, replacementValues)
			replace(&config.Steps[i].Auphonic.FileServer, replacementValues)

			for j := range config.Steps[i].Auphonic.Files {
				replace(&config.Steps[i].Auphonic.Files[j].Episode, replacementValues)
				replace(&config.Steps[i].Auphonic.Files[j].Image, replacementValues)
				replace(&config.Steps[i].Auphonic.Files[j].Chapters, replacementValues)
			}
		}
	}
	return config
}

func replace(replaceString *string, replacementValues ReplacementValues) {
	*replaceString = strings.Replace(*replaceString, "{{folderName}}", replacementValues.FolderName, -1)
	*replaceString = strings.Replace(*replaceString, "{{episodeNumber}}", replacementValues.EpisodeNumber, -1)

	ReplaceEnvVariable(replaceString)

}

func ReplaceEnvVariable(replaceString *string) {
	re := regexp.MustCompile("{{env.(.*?)}}")
	res := re.FindAllStringSubmatch(*replaceString, -1)

	for _, match := range res {
		envVar := match[1]
		value := os.Getenv(envVar)
		*replaceString = re.ReplaceAllString(*replaceString, value)
	}
}
