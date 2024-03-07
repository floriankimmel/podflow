package config

import (
	"os"
	"path/filepath"

	yaml "gopkg.in/yaml.v3"
)

const defaultConfigName = ".config"
const defaultConfigDir = "podflow"

type ConfigurationFile struct {
}

type ConfigurationReaderWriter interface {
	Read(path string) (Configuration, error)
	Path() (string, error)
	Write(config Configuration) error
	DoesNotExist(path string) bool
}

//nolint:all
func (file ConfigurationFile) DoesNotExist(path string) bool {
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

	err = os.WriteFile(path, data, 0600)

	if err != nil {
		return err
	}

	return nil
}
func GetConfigFileName() string {
	podflowConfigFile, envFound := os.LookupEnv("PODFLOW_CONFIG_FILE")
	if !envFound {
		podflowConfigFile = "config.yml"
	}
	return podflowConfigFile
}

func (io ConfigurationFile) Path() (string, error) {
	homeDir, err := os.UserHomeDir()
	podflowConfigFile := GetConfigFileName()
	configFilePath := filepath.Join(homeDir, defaultConfigName, defaultConfigDir, podflowConfigFile)
	if err != nil {
		return "", err
	}
	return configFilePath, nil

}
