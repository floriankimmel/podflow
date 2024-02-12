package config

import (
	"os"
	"path/filepath"
	"regexp"
	"strings"
)

type EpisodeFile struct {
    Name                string          `yaml:"name"`
    FileName            string          `yaml:"fileName"`
    Required            bool            `yaml:"required"`
    NotEmpty            bool            `yaml:"notEmpty"`
    UmlauteNotAllowed   bool            `yaml:"umlauteNotAllowed"`
}

type AuphonicFiles struct {
    Image               string          `yaml:"image"`
    Chapters            string          `yaml:"chapters"`
    Episode             string          `yaml:"episode"`
}

type Auphonic struct {
    Username            string          `yaml:"username"`
    Password            string          `yaml:"password"`
    Preset              string          `yaml:"preset"`
    FileServer          string          `yaml:"fileServer"`
    Title               string          `yaml:"title"`
    Files               []AuphonicFiles `yaml:"files"`

}

type S3Bucket struct {
    Region              string          `yaml:"region"`
    Name                string          `yaml:"name"`
    Files               []FtpFile       `yaml:"files"`
}

type S3 struct {
    Buckets             []S3Bucket      `yaml:"buckets"`
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

type Wordpress struct {
    ApiKey              string          `yaml:"apiKey"`
    Server              string          `yaml:"server"`
    Image               string          `yaml:"image"`
    Episode             string          `yaml:"episode"`
    ShowNotes           string          `yaml:"showNotes"`
    Chapter             string          `yaml:"chapter"`
}

type Step struct {
    FTP                 FTP             `yaml:"ftp"`
    Download            FTP             `yaml:"download"`
    S3                  S3              `yaml:"s3"`
    Auphonic            Auphonic        `yaml:"auphonic"`
    Wordpress           Wordpress       `yaml:"wordpress"`
}
 
type Configuration struct {
    CurrentEpisode      string          `yaml:"currentEpisode"`
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

type ReplacementValues struct {
    EpisodeNumber string
    FolderName string
}

func LoadAndReplacePlaceholders(io ConfigurationReaderWriter, dir string) (Configuration, error) {
    config, err := Load(io)

    if err != nil {
        return Configuration{}, err
    }
    replacementValues := ReplacementValues{
        EpisodeNumber: config.CurrentEpisode,
        FolderName: filepath.Base(dir),
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
            replace(&config.Steps[i].Wordpress.ShowNotes, replacementValues)
            replace(&config.Steps[i].Wordpress.ApiKey, replacementValues)
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


