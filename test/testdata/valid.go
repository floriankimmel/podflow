package testdata

import config "podflow/internal/configuration"

type ValidConfigurationFile struct{}

func (file ValidConfigurationFile) Read(path string) (config.Configuration, error) {
	podflowConfig := config.Configuration{
		CurrentEpisode: "1",
		ReleaseDay:     "Friday",
		ReleaseTime:    "09:00:00",
		Files: []config.EpisodeFile{
			{
				Name:              "Podflow",
				FileName:          "{{folderName}}.mp3",
				Required:          true,
				UmlauteNotAllowed: true,
			},
			{
				Name:     "Podflow",
				FileName: "{{folderName}}.md",
				NotEmpty: true,
			},
		},
		Steps: []config.Step{
			{
				FTP: config.FTP{
					Files: []config.FtpFile{
						{
							Source: "{{episodeNumber}}_{{folderName}}.mp3",
							Target: "{{episodeNumber}}_{{folderName}}.mp3",
						},
					},
				},
			},
			{
				Auphonic: config.Auphonic{
					Title: "{{episodeTitle}}",
					Files: []config.AuphonicFiles{
						{
							Chapters: "{{episodeNumber}}_{{folderName}}.chapters.txt",
							Image:    "{{episodeNumber}}_{{folderName}}.png",
							Episode:  "{{episodeNumber}}_{{folderName}}.mp3",
						},
					},
				},
			},
		},
	}
	return podflowConfig, nil
}

func (file ValidConfigurationFile) Path() (string, error) {
	return "~/unit-tests/config.yaml", nil
}
func (file ValidConfigurationFile) Write(config config.Configuration) error {
	return nil
}

func (file ValidConfigurationFile) DoesNotExist(path string) bool {
	return false
}
