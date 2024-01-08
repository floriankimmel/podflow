package cmd

import (
	"bufio"
	"fmt"
	"os"
	"podflow/internal/configuration"
	"podflow/internal/targets"
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
        fmt.Println(" Error: " + err.Error())
        return err
    }

    slug := config.EpisodeSlug()
    podflowConfig, err := config.LoadAndReplacePlaceholders()

    if err != nil {
        fmt.Println(" Error: " + err.Error())
        return err
    }

    fmt.Println("")
    fmt.Printf(" Start automatic workflow for file %s \n", slug)
    releaseInfo := config.GetReleaseInformation()
    episodeNumber := releaseInfo.EpisodeNumber + 1
    nextReleaseDate := releaseInfo.NextReleaseDate

    fmt.Printf(" Episode number: %d \n", episodeNumber)
    fmt.Printf(" Next release date: %s \n", nextReleaseDate)
    scanner := bufio.NewScanner(os.Stdin)
    fmt.Print(" Enter episode title: ")
    scanner.Scan()
    episodeTitle := scanner.Text()
    fmt.Printf(" Episode title: %s \n\n", episodeTitle)
 
    for i := range podflowConfig.Steps {
        step := podflowConfig.Steps[i]
        if step.Target.FTP != (config.FTP{}) {
            err:= targets.FtpUpload(step.Target.FTP, step.Files)
            if err != nil {
                return err
            }
        }
    }

    nextEpisodeNumber := releaseInfo.EpisodeNumber + 1
    if err := config.SetEpisodeNumber(nextEpisodeNumber); err != nil {
        return err
    }
    return nil
}
