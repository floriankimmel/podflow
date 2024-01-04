package cmd

import (
	"bufio"
	"fmt"
	"os"
	"podflow/configuration"
)

func Publish() error {
    fmt.Println("")
    fmt.Println("██╗     ███████╗██████╗      ██████╗██╗     ██╗")
    fmt.Println("██║     ██╔════╝██╔══██╗    ██╔════╝██║     ██║")
    fmt.Println("██║     █████╗  ██████╔╝    ██║     ██║     ██║")
    fmt.Println("██║     ██╔══╝  ██╔═══╝     ██║     ██║     ██║")
    fmt.Println("███████╗███████╗██║         ╚██████╗███████╗██║")
    fmt.Println("╚══════╝╚══════╝╚═╝          ╚═════╝╚══════╝╚═╝")
    fmt.Println("")

    err := Check()
    if err != nil {
        return err
    }

    episode := config.Episode()

    fmt.Println("")
    fmt.Printf(" Start automatic workflow for file %s \n", episode)
    metadata := config.GetMetadata()
    episodeNumber := metadata.EpisodeNumber + 1
    nextReleaseDate := metadata.NextReleaseDate

    fmt.Printf(" Episode number: %d \n", episodeNumber)
    fmt.Printf(" Next release date: %s \n", nextReleaseDate)
    scanner := bufio.NewScanner(os.Stdin)
    fmt.Print(" Enter episode title: ")
    scanner.Scan()
    episodeTitle := scanner.Text()
    fmt.Printf(" Episode title: %s \n", episodeTitle)
 
    return nil

}
