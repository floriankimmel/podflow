package cmd

import (
	"errors"
	"os"
	"path/filepath"
	"regexp"
	"strings"

	"github.com/fatih/color"
)

func Check(skipYoutube bool) error {
    ready := true

    dir, _ := os.Getwd()
    folderName := filepath.Base(dir)
    files, _ := os.ReadDir(dir)

    if match, _ := regexp.MatchString("[äöüÄÖÜ]", folderName); match {
        color.Red(" Episode title contains Umlaute")
        ready = false
    } else {
        color.Green(" Episode title does not have Umlaute")
    }

    if fileExists(files, folderName + ".m4a") {
        color.Green(" Episode is already exported")
    } else {
        color.Red(" No Episode is exported to automate")
        ready = false
    }

    if fileExists(files, folderName + "_addfree.m4a") {
        color.Green(" Adfree Episode is already exported")
    } else {
        color.Yellow(" No Adfree Episode")
    }

    if fileExists(files, folderName + ".md") {
        color.Green(" Episode description exists")
    } else {
        color.Red(" No Episode description available")
        ready = false
    }

    if isNotEmpty(files, folderName + ".md") {
        color.Green(" Episode description is not empty")
    } else {
        color.Red(" Episode description is empty")
        ready = false
    }

    if fileExists(files, folderName + ".png") {
        color.Green(" Episode thumbnail exists")
    } else {
        color.Red(" No Episode thumbnail available")
        ready = false
    }

    if !skipYoutube {
        if fileExists(files, folderName + "_youtube.png") {
            color.Green(" Episode youtube thumbnail exists")
        } else {
            color.Red(" No Episode youtube thumbnail available")
            ready = false
        }
    } 

    if fileExists(files, folderName + ".chapters.txt") {
        color.Green(" Episode chapters exists")
    } else {
        color.Red(" No Episode chapters available")
        ready = false
    }

    if !ready {
        return errors.New("Not all requirements are met")
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
