package config

import (
	"os"
	"path/filepath"
)

func Episode() string {
    dir, _ := os.Getwd()
    folderName := filepath.Base(dir)
    return folderName + ".m4a"
}

func Dir() string {
    dir, _ := os.Getwd()
    return dir
}
