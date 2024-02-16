package config

import (
	"os"
	"path/filepath"
)

func EpisodeSlug(dir string) string {
	folderName := filepath.Base(dir)
	return folderName + ".m4a"
}

func Dir() string {
	dir, _ := os.Getwd()
	return dir
}
