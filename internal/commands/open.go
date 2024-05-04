package cmd

import (
	"fmt"
	config "podflow/internal/configuration"
	"podflow/internal/state"

	"github.com/pkg/browser"
)

func Open(
	stateIo state.StateReaderWriter,
	workingDir string,
	io config.ConfigurationReaderWriter,
) error {
	currentState, _ := stateIo.Read()
	wordPressID := currentState.Wordpress.WordpressID

	podflowConfig, err := config.LoadAndReplacePlaceholders(io, workingDir)

	if err != nil {
		return err
	}
	host := ""
	for _, step := range podflowConfig.Steps {
		if step.Wordpress != (config.Wordpress{}) {
			host = step.Wordpress.Server
		}
	}
	url := fmt.Sprintf("%s/wp-admin/post.php?post=%s&action=edit", host, wordPressID)
	err = browser.OpenURL(url)
	if err != nil {
		return err
	}
	return nil

}
