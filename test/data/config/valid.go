package testData

import config "podflow/internal/configuration"

type ValidConfigurationFile struct {
}

func (file ValidConfigurationFile) Read(path string) (config.Configuration, error) {
    podflowConfig := config.Configuration{
        CurrentEpisode: 1,
        ReleaseDay: "Friday",
        ReleaseTime: "09:00:00",
        Files: []config.File{
            {
                Name: "Podflow",
                FileName: "podflow.mp3",
                Required: true,
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

func (file ValidConfigurationFile) IsNotExist(path string) bool {
    return false
}
