package config

import (
	"os"
	"path/filepath"
)

func EpisodeSlug() string {
    dir, _ := os.Getwd()
    folderName := filepath.Base(dir)
    return folderName + ".m4a"
}

func Dir() string {
    dir, _ := os.Getwd()
    return dir
}
