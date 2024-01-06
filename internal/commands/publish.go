package cmd

import (
	"bufio"
	"fmt"
	"os"
	"podflow/internal/configuration"
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

    slug := config.EpisodeSlug()

    fmt.Println("")
    fmt.Printf(" Start automatic workflow for file %s \n", slug)
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
 
    nextEpisodeNumber := metadata.EpisodeNumber + 1
    if err := config.SetEpisodeNumber(nextEpisodeNumber); err != nil {
        return err
    }
    return nil

}
