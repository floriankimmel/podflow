package cmd

import (
	"fmt"
	"path/filepath"
	config "podflow/internal/configuration"
	"podflow/internal/input"
	"podflow/internal/state"
	"podflow/internal/targets"
	"podflow/internal/targets/wordpress"
	"strconv"
	"strings"
	"time"

	"github.com/fatih/color"
)

const errorPrefix = " Error: "

func Publish(
	io config.ConfigurationReaderWriter,
	stateIo state.StateReaderWriter,
	userInput input.Input,
	workingDir string,
) error {
	if err := Check(io, workingDir); err != nil {
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
	fmt.Printf(" Start automatic workflow for file %s \n", config.EpisodeSlug(workingDir))
	replacementValues := config.ReplacementValues{
		FolderName: filepath.Base(workingDir),
	}

	if currentState.Metadata == (state.Metadata{}) || currentState.Metadata.EpisodeNumber == "" {
		releaseInfo := config.GetReleaseInformation(io, time.Now())

		number, _ := strconv.Atoi(releaseInfo.EpisodeNumber)
		episodeNumber := number + 1
		nextReleaseDate := releaseInfo.NextReleaseDate

		fmt.Printf(" Episode number: %d \n", episodeNumber)
		fmt.Printf(" Next release date: %s \n", nextReleaseDate)

		episodeTitle := userInput.Text(" Enter episode title: ")

		currentState.Metadata = state.Metadata{
			EpisodeNumber: strconv.Itoa(episodeNumber),
			ReleaseDate:   nextReleaseDate,
			Title:         episodeTitle,
		}

		if err := stateIo.Write(currentState); err != nil {
			return err
		}

		replacementValues.EpisodeNumber = strconv.Itoa(episodeNumber)

		if err := config.SetEpisodeNumber(io, strconv.Itoa(episodeNumber)); err != nil {
			return err
		}

		fmt.Println("")

	} else {
		fmt.Printf(" Episode number: %s \n", currentState.Metadata.EpisodeNumber)
		fmt.Printf(" Next release date: %s \n", currentState.Metadata.ReleaseDate)
		fmt.Printf(" Episode title: %s", currentState.Metadata.Title)

		replacementValues.EpisodeNumber = currentState.Metadata.EpisodeNumber

	}
	replacedPodflowConfig := config.ReplacePlaceholders(podflowConfig, replacementValues)

	for i := range replacedPodflowConfig.Steps {
		step := replacedPodflowConfig.Steps[i]
		if len(step.FTP.Files) > 0 {
			fmt.Printf("\n\n[%d/%d] FTP \n", (i + 1), len(replacedPodflowConfig.Steps))
			if !currentState.FTPUploaded {
				err := targets.FtpUpload(step)
				if err != nil {
					color.Red(errorPrefix + err.Error())
					return err
				}

				currentState.FTPUploaded = true
				if err := stateIo.Write(currentState); err != nil {
					return err
				}
				color.Green("  FTP upload done")
			} else {
				color.Green("  FTP upload skipped")
			}
		}

		if len(step.Download.Files) > 0 {
			fmt.Printf("\n\n[%d/%d] Download \n", (i + 1), len(replacedPodflowConfig.Steps))
			if !currentState.Downloaded {
				err := targets.FtpDownload(step)
				if err != nil {
					color.Red(errorPrefix + err.Error())
					return err
				}

				currentState.Downloaded = true
				if err := stateIo.Write(currentState); err != nil {
					return err
				}
				color.Green("  Download done")
			} else {
				color.Green("  Download skipped")
			}
		}

		if len(step.S3.Buckets) > 0 {
			fmt.Printf("\n\n[%d/%d] Amazon S3 \n", (i + 1), len(replacedPodflowConfig.Steps))
			if !currentState.S3Uploaded {
				err := targets.S3Upload(step.S3)
				if err != nil {
					color.Red(errorPrefix + err.Error())
					return err
				}

				currentState.S3Uploaded = true
				if err := stateIo.Write(currentState); err != nil {
					return err
				}
				color.Green("  S3 upload done")
			} else {
				color.Green("  S3 upload skipped")
			}
		}
		if step.Wordpress != (config.Wordpress{}) {
			fmt.Printf("\n\n[%d/%d] Wordpress \n", (i + 1), len(replacedPodflowConfig.Steps))
			if !currentState.WordpressBlogCreated {
				_, err := wordpress.ScheduleEpisode(
					step.Wordpress,
					stateIo,
					currentState.Metadata.Title,
					currentState.Metadata.EpisodeNumber,
					currentState.Metadata.ReleaseDate,
				)

				if err != nil {
					color.Red(errorPrefix + err.Error())
					return err
				}

				currentState, _ = stateIo.Read()
				currentState.WordpressBlogCreated = true
				if err := stateIo.Write(currentState); err != nil {
					return err
				}
				color.Green("  Wordpress production done")
			} else {
				color.Green("  Wordpress production skipped")
			}
		}

		if step.SteadyHq != (config.SteadyHq{}) {
			fmt.Printf("\n\n[%d/%d] SteadyHq \n", (i + 1), len(replacedPodflowConfig.Steps))
			if !currentState.SteadyHqCreated {
				step.SteadyHq.Title = strings.Replace(step.SteadyHq.Title, "{{episodeTitle}}", currentState.Metadata.Title, -1)

				err := targets.ScheduleSteadyHq(
					step.SteadyHq,
					currentState.Metadata.ReleaseDate,
				)

				if err != nil {
					color.Red(errorPrefix + err.Error())
					return err
				}

				currentState, _ = stateIo.Read()
				currentState.SteadyHqCreated = true
				if err := stateIo.Write(currentState); err != nil {
					return err
				}
				color.Green("  Steady production done")
			} else {
				color.Green("  Steady production skipped")
			}
		}

		if len(step.Auphonic.Title) > 0 {
			fmt.Printf("\n\n[%d/%d] Auphonic \n", (i + 1), len(replacedPodflowConfig.Steps))
			if !currentState.AuphonicProduction {
				step.Auphonic.Title = strings.Replace(step.Auphonic.Title, "{{episodeTitle}}", currentState.Metadata.Title, -1)
				_, err := targets.StartAuphonicProduction("https://auphonic.com", step, 20)

				if err != nil {
					color.Red(errorPrefix + err.Error())
					return err
				}

				currentState.AuphonicProduction = true
				if err := stateIo.Write(currentState); err != nil {
					return err
				}
				color.Green("  Auphonic production done")
			} else {
				color.Green("  Auphonic production skipped")
			}
		}
	}

	return nil
}
