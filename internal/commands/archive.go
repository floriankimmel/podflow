package cmd

import (
	"fmt"
	"os"
	"path/filepath"
	config "podflow/internal/configuration"
	"podflow/internal/state"
)
func Archive(
	stateIo state.StateReaderWriter,
	io config.ConfigurationReaderWriter,
	workingDir string,
) error {
	fmt.Println(" Target directory: " + workingDir)

	err := os.Chdir(workingDir)

	if (err != nil) {
		fmt.Println(" Error: " + err.Error())
		return fmt.Errorf("failed to move folder: %w", err)
	}

	podflowConfig, err := config.Load(io)

	if err != nil {
		return err
	}

	currentState, err := stateIo.Read()

	if err != nil {
		fmt.Println(" Error: " + err.Error())
		return err
	}

	replacementValues := config.ReplacementValues{
		FolderName: filepath.Base(workingDir),
		EpisodeNumber: currentState.Metadata.EpisodeNumber,
	}

	replacedPodflowConfig := config.ReplacePlaceholders(podflowConfig, replacementValues)


	if (replacedPodflowConfig.Archive != (config.Archive{})) {
		fmt.Println(" Archiving folder " + filepath.Base(workingDir) + " to " + filepath.Base(replacedPodflowConfig.Archive.Target))

		err := os.Rename(workingDir, replacedPodflowConfig.Archive.Target)
		if (err != nil) {
			fmt.Println(" Error: " + err.Error())
		    return fmt.Errorf("failed to move and rename folder: %w", err)
		}

	}

	return nil
}

