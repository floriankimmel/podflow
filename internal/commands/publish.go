package cmd

import (
	"fmt"
	config "podflow/internal/configuration"
	"podflow/internal/input"
	"podflow/internal/state"
	"podflow/internal/targets"
	"strings"
	"time"
)


func Publish(io config.ConfigurationReaderWriter, stateIo state.StateReaderWriter, input input.Input, dir string) error {
    if err := Check(io, dir); err != nil {
        fmt.Println(" Error: " + err.Error())
        return err
    }

    currentState, err := stateIo.Read()

    if err != nil {
        return err
    }

    podflowConfig, err := config.Load(io)

    if err != nil {
        fmt.Println(" Error: " + err.Error())
        return err
    }

    fmt.Println("")
    fmt.Printf(" Start automatic workflow for file %s \n", config.EpisodeSlug(dir))

    if currentState.Metadata == (state.Metadata{}) {
        releaseInfo := config.GetReleaseInformation(io, time.Now())

        episodeNumber := releaseInfo.EpisodeNumber + 1
        nextReleaseDate := releaseInfo.NextReleaseDate

        fmt.Printf(" Episode number: %d \n", episodeNumber)
        fmt.Printf(" Next release date: %s \n", nextReleaseDate)

        fmt.Print(" Enter episode title: ")
        episodeTitle := input.Text()

        currentState.Metadata = state.Metadata{
            EpisodeNumber: episodeNumber,
            ReleaseDate: nextReleaseDate,
            Title: episodeTitle,
        }

        if err := stateIo.Write(currentState); err != nil {
            return err
        }

        nextEpisodeNumber := currentState.Metadata.EpisodeNumber + 1
        if err := config.SetEpisodeNumber(io, nextEpisodeNumber); err != nil {

            return err
        }

        fmt.Println("")

    } else {
        fmt.Printf(" Episode number: %d \n", currentState.Metadata.EpisodeNumber)
        fmt.Printf(" Next release date: %s \n", currentState.Metadata.ReleaseDate)
        fmt.Printf(" Episode title: %s \n\n", currentState.Metadata.Title)

        podflowConfig.CurrentEpisode = currentState.Metadata.EpisodeNumber
    }

    replacedPodflowConfig := config.ReplacePlaceholders(podflowConfig, dir)
 
    for i := range replacedPodflowConfig.Steps {
        step := replacedPodflowConfig.Steps[i]
        if len(step.FTP.Files) > 0 {
            if !currentState.FTPUploaded {
                err:= targets.FtpUpload(step)
                if err != nil {
                    return err
                }

                currentState.FTPUploaded = true
                if err := stateIo.Write(currentState); err != nil {
                    return err
                }
            } else {
                fmt.Println(" FTP upload skipped")
            }
        }

        if len(step.Download.Files) > 0 {
            if !currentState.Downloaded {
                err:= targets.FtpDownload(step)
                if err != nil {
                    return err
                }

                currentState.Downloaded = true
                if err := stateIo.Write(currentState); err != nil {
                    return err
                }
            } else {
                fmt.Println(" Download skipped")
            }
        }

        if step.Auphonic != (config.Auphonic{}) {
            if !currentState.AuphonicProduction {
                step.Auphonic.Title = strings.Replace(step.Auphonic.Title, "{{episodeTitle}}", currentState.Metadata.Title, -1)
                err:= targets.StartAuphonicProduction("https://auphonic.com", step)


                if err != nil {
                    return err
                }

                currentState.AuphonicProduction = true
                if err := stateIo.Write(currentState); err != nil {
                    return err
                }
            } else {
                fmt.Println(" Auphonic production skipped")
            }
        }
    }

    return nil
}
