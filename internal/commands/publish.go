package cmd

import (
	"bufio"
	"fmt"
	"os"
	"podflow/internal/configuration"
	"podflow/internal/state"
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

    if err := Check(); err != nil {
        fmt.Println(" Error: " + err.Error())
        return err
    }

    io := config.ConfigurationFile{}
    stateFile := state.StateFile{}
    currentState, err := stateFile.Read()

    if err != nil {
        return err
    }

    podflowConfig, err := config.Load(io)

    if err != nil {
        fmt.Println(" Error: " + err.Error())
        return err
    }

    fmt.Println("")
    fmt.Printf(" Start automatic workflow for file %s \n", config.EpisodeSlug())

    if currentState.Metadata == (state.Metadata{}) {
        releaseInfo := config.GetReleaseInformation(io)

        episodeNumber := releaseInfo.EpisodeNumber + 1
        nextReleaseDate := releaseInfo.NextReleaseDate

        fmt.Printf(" Episode number: %d \n", episodeNumber)
        fmt.Printf(" Next release date: %s \n", nextReleaseDate)

        scanner := bufio.NewScanner(os.Stdin)
        fmt.Print(" Enter episode title: ")
        scanner.Scan()
        episodeTitle := scanner.Text()

        currentState.Metadata = state.Metadata{
            EpisodeNumber: episodeNumber,
            ReleaseDate: nextReleaseDate,
            Title: episodeTitle,
        }

        if err := stateFile.Write(currentState); err != nil {
            return err
        }

        nextEpisodeNumber := currentState.Metadata.EpisodeNumber + 1
        if err := config.SetEpisodeNumber(io, nextEpisodeNumber); err != nil {

            return err
        }

    } else {
        fmt.Printf(" Episode number: %d \n", currentState.Metadata.EpisodeNumber)
        fmt.Printf(" Next release date: %s \n", currentState.Metadata.ReleaseDate)
        fmt.Printf(" Episode title: %s \n\n", currentState.Metadata.Title)

        podflowConfig.CurrentEpisode = currentState.Metadata.EpisodeNumber
    }

    replacedPodflowConfig := config.ReplacePlaceholders(podflowConfig)
 
    for i := range replacedPodflowConfig.Steps {
        step := replacedPodflowConfig.Steps[i]
        if step.Target.FTP != (config.FTP{}) {
            if !currentState.FTPUploaded {
                err:= targets.FtpUpload(step)
                if err != nil {
                    return err
                }

                currentState.FTPUploaded = true
                if err := stateFile.Write(currentState); err != nil {
                    return err
                }
            } else {
                fmt.Println(" FTP upload skipped")
            }
        }
    }

    return nil
}
