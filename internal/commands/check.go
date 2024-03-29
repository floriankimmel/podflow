package cmd

import (
	"errors"
	"os"
	"regexp"
	"strings"

	config "podflow/internal/configuration"

	"github.com/fatih/color"
)

const check = " "

func Check(io config.ConfigurationReaderWriter, dir string) error {
	ready := true

	files, _ := os.ReadDir(dir)
	config, err := config.LoadAndReplacePlaceholders(io, dir)

	if err != nil {
		return err
	}

	pattern, _ := regexp.Compile("[äöüÄÖÜ]")

	for _, file := range config.Files {
		if fileExists(files, file.FileName) {
			color.Green(check + file.Name + " is already exported")
		} else {
			if file.Required {
				color.Red(" No " + file.Name + " is exported")
				ready = false
			} else {
				color.Yellow(" No " + file.Name)
			}
		}

		if file.UmlauteNotAllowed {
			if match := pattern.MatchString(file.FileName); match {
				color.Red(" " + file.Name + " contains Umlaute")
				ready = false
			} else {
				color.Green(check + file.Name + " does not have Umlaute")
			}
		}

		if file.NotEmpty {
			if isNotEmpty(files, file.FileName) {
				color.Green(check + file.Name + " is not empty")
			} else {
				color.Red(" " + file.Name + " is empty")
				ready = false
			}

		}
	}

	if !ready {
		return errors.New("not all requirements are met")
	}

	return nil
}

func isNotEmpty(files []os.DirEntry, desiredFile string) bool {
	file := findFile(files, desiredFile)

	if file != nil {
		info, _ := file.Info()
		return info.Size() > 0
	}

	return false
}

func fileExists(files []os.DirEntry, desiredFile string) bool {
	return findFile(files, desiredFile) != nil
}

func findFile(files []os.DirEntry, desiredFile string) os.DirEntry {
	for _, file := range files {
		if !file.IsDir() && strings.EqualFold(file.Name(), desiredFile) {
			return file
		}
	}
	return nil
}
