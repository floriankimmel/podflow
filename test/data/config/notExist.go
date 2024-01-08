package testData

import config "podflow/internal/configuration"

type NonExistingConfigurationFile struct {
}

func (file NonExistingConfigurationFile) Read(path string) (config.Configuration, error) {
    return config.Configuration{}, nil
}

func (file NonExistingConfigurationFile) Path() (string, error) {
    return "~/unit-tests/config.yaml", nil
}
func (file NonExistingConfigurationFile) Write(config config.Configuration) error {
    return nil
}

func (file NonExistingConfigurationFile) IsNotExist(path string) bool {
    return true
}
