package cmd

import (
	"fmt"
	"os"
	"path/filepath"
	config "podflow/internal/configuration"
	"podflow/internal/state"

	"github.com/fatih/color"
)

func State(
	stateIo state.StateReaderWriter,
	workingDir string,
	io config.ConfigurationReaderWriter,
) error {
	currentState, _ := stateIo.Read()
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

	fmt.Printf(" Episode number: %s \n", currentState.Metadata.EpisodeNumber)
	fmt.Printf(" Next release date: %s \n", currentState.Metadata.ReleaseDate)
	fmt.Printf(" Episode title: %s\n\n", currentState.Metadata.Title)

	wordPressID := currentState.Wordpress.WordpressID
	fmt.Printf(" Wordpress Id: %s\n", wordPressID)
	fmt.Printf(" Podlove Id: %s\n", currentState.Wordpress.PodloveID)
	fmt.Printf(" Featured media Id: %s\n\n", currentState.Wordpress.FeaturedMediaID)
	fmt.Printf(" Wordpress: %s\n\n", fmt.Sprintf("%s/wp-admin/post.php?post=%s&action=edit", host, wordPressID))

	if currentState.FTPUploaded {
		color.Green(" FTP uploaded")
	} else {
		color.Red(" FTP not uploaded")
	}

	if currentState.S3Uploaded {
		color.Green(" S3 uploaded")
	} else {
		color.Red(" S3 not uploaded")
	}

	if currentState.AuphonicProduction {
		color.Green(" Auphonic production")
	} else {
		color.Red(" Auphonic not produced")
	}

	if currentState.WordpressBlogCreated {
		color.Green(" Wordpress blog created")
	} else {
		color.Red(" Wordpress blog not created")
	}

	if currentState.Downloaded {
		color.Green(" Downloaded")
	} else {
		color.Red(" Not downloaded")
	}

	if len(currentState.ChapterMarks) > 0 {
		fmt.Println("\n󰙒 Chapter marks")
		chapterFilePath := filepath.Join(workingDir, filepath.Base(workingDir)+".chapters.txt")
		if _, err := os.Stat(chapterFilePath); os.IsNotExist(err) {
			color.Red(" Chapters not exported")
		} else {
			content, _ := os.ReadFile(chapterFilePath)
			fmt.Printf("%s", content)
		}
	}

	return nil
}
