package testData

import (
	"os"
	"path/filepath"
	config "podflow/internal/configuration"
	"podflow/internal/state"

	"gopkg.in/yaml.v3"
)

type TempConfigurationFile struct {
    config.ConfigurationFile
}

func (file TempConfigurationFile) Path() (string, error) {
    return filepath.Join(os.TempDir(), "podflow", "podflow.yml"), nil
}

func (file TempConfigurationFile) Write(config config.Configuration) error {
    path, err := file.Path()

    if err != nil {
        return err
    }

    data, err := yaml.Marshal(config)

    if err != nil {
        return err
    }

    err = os.WriteFile(path, data, 0644)

    if err != nil {
        return err
    }

    return nil
}

type TempStateFile struct {
}
func (file TempStateFile) Read() (state.State, error) {
    stateFilePath := file.GetStateFilePath()

    data, err := os.ReadFile(stateFilePath)

    if err != nil {
        return state.State{}, err
    }

    config := state.State{}
    
    if err := yaml.Unmarshal(data, &config); err != nil {
        return state.State{}, err
    }

    return config, nil
}

func (file TempStateFile) Write(state state.State) error {
    stateFilePath := file.GetStateFilePath()

    data, err := yaml.Marshal(state)

    if err != nil {
        return err
    }

    err = os.WriteFile(stateFilePath, data, 0644)

    if err != nil {
        return err
    }

    return nil
}


func (file TempStateFile) GetStateFilePath() string {
    return filepath.Join(os.TempDir(), "podflow", "podflow.state.yml")
}
