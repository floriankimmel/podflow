package cmd

import (
	"fmt"
	"os"
	"path/filepath"
	"podflow/internal/state"

	"github.com/fatih/color"
)

func State(stateIo state.StateReaderWriter, dir string) error {
	currentState, _ := stateIo.Read()

	fmt.Printf(" Episode number: %d \n", currentState.Metadata.EpisodeNumber)
	fmt.Printf(" Next release date: %s \n", currentState.Metadata.ReleaseDate)
	fmt.Printf(" Episode title: %s\n\n", currentState.Metadata.Title)

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
		chapterFilePath := filepath.Join(dir, filepath.Base(dir)+".chapters.txt")
		if _, err := os.Stat(chapterFilePath); os.IsNotExist(err) {
			color.Red(" Chapters not exported")
		} else {
			content, _ := os.ReadFile(chapterFilePath)
			fmt.Printf("%s", content)
		}
	}

	return nil
}
