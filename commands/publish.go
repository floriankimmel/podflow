package cmd

import (
	"fmt"
	"os"
	"path/filepath"
)

func Publish(skipFtp bool, skipAws bool, skipAuphonic bool, skipDownload bool, skipBlogpost bool, skipYoutube bool) error {
    dir, _ := os.Getwd()
    folderName := filepath.Base(dir)
    episode := folderName + ".m4a"

    fmt.Println("")
    fmt.Println("██╗     ███████╗██████╗      ██████╗██╗     ██╗")
    fmt.Println("██║     ██╔════╝██╔══██╗    ██╔════╝██║     ██║")
    fmt.Println("██║     █████╗  ██████╔╝    ██║     ██║     ██║")
    fmt.Println("██║     ██╔══╝  ██╔═══╝     ██║     ██║     ██║")
    fmt.Println("███████╗███████╗██║         ╚██████╗███████╗██║")
    fmt.Println("╚══════╝╚══════╝╚═╝          ╚═════╝╚══════╝╚═╝")
    fmt.Println("")

    err := Check(skipYoutube)
    if err != nil {
        return err
    }

    fmt.Println("")
    fmt.Printf(" Start automatic workflow for file %s \n", episode)
 
    return nil

}
