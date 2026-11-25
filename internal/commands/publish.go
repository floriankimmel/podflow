package cmd

import (
	"fmt"
	"path/filepath"
	"github.com/floriankimmel/podflow/internal/backend"
	config "github.com/floriankimmel/podflow/internal/configuration"
	"github.com/floriankimmel/podflow/internal/input"
	"github.com/floriankimmel/podflow/internal/state"
	"github.com/floriankimmel/podflow/internal/targets"
	"github.com/floriankimmel/podflow/internal/targets/wordpress"
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

	// Best-effort backend reporting: nil reporter (unconfigured) is a no-op,
	// and failures never interrupt the publish pipeline.
	backendConfig := podflowConfig.ResolvedBackend()
	reporter := backend.New(backendConfig.URL, backendConfig.WorkspaceKey)
	episodeMetadata := backend.Metadata{
		EpisodeNumber: currentState.Metadata.EpisodeNumber,
		Title:         currentState.Metadata.Title,
		ReleaseDate:   currentState.Metadata.ReleaseDate,
	}
	report := func(step string, status string) {
		reporter.Report(episodeMetadata, step, status)
	}

	for i := range replacedPodflowConfig.Steps {
		step := replacedPodflowConfig.Steps[i]
		if len(step.FTP.Delete) > 0 {
			fmt.Printf("\n\n[%d/%d] Delete FTP files \n", (i + 1), len(replacedPodflowConfig.Steps))
			if !currentState.FTPDeleted {
				report("ftp_delete", backend.StatusInProgress)
				err := targets.FtpDelete(step)
				if err != nil {
					report("ftp_delete", backend.StatusFailed)
					color.Red(errorPrefix + err.Error())
					return err
				}

				currentState.FTPDeleted = true
				if err := stateIo.Write(currentState); err != nil {
					return err
				}
				report("ftp_delete", backend.StatusDone)
				color.Green("  FTP deletion done")
			} else {
				report("ftp_delete", backend.StatusDone)
				color.Green("  FTP deletion skipped")
			}
		}

		if len(step.FTP.Files) > 0 {
			fmt.Printf("\n\n[%d/%d] FTP \n", (i + 1), len(replacedPodflowConfig.Steps))
			if !currentState.FTPUploaded {
				report("ftp_upload", backend.StatusInProgress)
				err := targets.FtpUpload(step)
				if err != nil {
					report("ftp_upload", backend.StatusFailed)
					color.Red(errorPrefix + err.Error())
					return err
				}

				currentState.FTPUploaded = true
				if err := stateIo.Write(currentState); err != nil {
					return err
				}
				report("ftp_upload", backend.StatusDone)
				color.Green("  FTP upload done")
			} else {
				report("ftp_upload", backend.StatusDone)
				color.Green("  FTP upload skipped")
			}
		}

		if len(step.Download.Files) > 0 {
			fmt.Printf("\n\n[%d/%d] Download \n", (i + 1), len(replacedPodflowConfig.Steps))
			if !currentState.Downloaded {
				report("download", backend.StatusInProgress)
				err := targets.FtpDownload(step)
				if err != nil {
					report("download", backend.StatusFailed)
					color.Red(errorPrefix + err.Error())
					return err
				}

				currentState.Downloaded = true
				if err := stateIo.Write(currentState); err != nil {
					return err
				}
				report("download", backend.StatusDone)
				color.Green("  Download done")
			} else {
				report("download", backend.StatusDone)
				color.Green("  Download skipped")
			}
		}

		if len(step.S3.Buckets) > 0 {
			fmt.Printf("\n\n[%d/%d] Amazon S3 \n", (i + 1), len(replacedPodflowConfig.Steps))
			if !currentState.S3Uploaded {
				report("s3", backend.StatusInProgress)
				err := targets.S3Upload(step.S3)
				if err != nil {
					report("s3", backend.StatusFailed)
					color.Red(errorPrefix + err.Error())
					return err
				}

				currentState.S3Uploaded = true
				if err := stateIo.Write(currentState); err != nil {
					return err
				}
				report("s3", backend.StatusDone)
				color.Green("  S3 upload done")
			} else {
				report("s3", backend.StatusDone)
				color.Green("  S3 upload skipped")
			}
		}
		if step.Wordpress != (config.Wordpress{}) {
			fmt.Printf("\n\n[%d/%d] Wordpress \n", (i + 1), len(replacedPodflowConfig.Steps))
			if !currentState.WordpressBlogCreated {
				report("wordpress", backend.StatusInProgress)
				_, err := wordpress.ScheduleEpisode(
					step.Wordpress,
					stateIo,
					currentState.Metadata.Title,
					currentState.Metadata.EpisodeNumber,
					currentState.Metadata.ReleaseDate,
				)

				if err != nil {
					report("wordpress", backend.StatusFailed)
					color.Red(errorPrefix + err.Error())
					return err
				}

				currentState, _ = stateIo.Read()
				currentState.WordpressBlogCreated = true
				if err := stateIo.Write(currentState); err != nil {
					return err
				}
				report("wordpress", backend.StatusDone)
				color.Green("  Wordpress production done")
			} else {
				report("wordpress", backend.StatusDone)
				color.Green("  Wordpress production skipped")
			}
		}

		if step.SteadyHq != (config.SteadyHq{}) {
			fmt.Printf("\n\n[%d/%d] SteadyHq \n", (i + 1), len(replacedPodflowConfig.Steps))
			if !currentState.SteadyHqCreated {
				report("steady", backend.StatusInProgress)
				step.SteadyHq.Title = strings.ReplaceAll(step.SteadyHq.Title, "{{episodeTitle}}", currentState.Metadata.Title)

				err := targets.ScheduleSteadyHq(
					step.SteadyHq,
					currentState.Metadata.ReleaseDate,
				)

				if err != nil {
					report("steady", backend.StatusFailed)
					color.Red(errorPrefix + err.Error())
					return err
				}

				currentState, _ = stateIo.Read()
				currentState.SteadyHqCreated = true
				if err := stateIo.Write(currentState); err != nil {
					return err
				}
				report("steady", backend.StatusDone)
				color.Green("  Steady production done")
			} else {
				report("steady", backend.StatusDone)
				color.Green("  Steady production skipped")
			}
		}

		if len(step.Auphonic.Title) > 0 {
			fmt.Printf("\n\n[%d/%d] Auphonic \n", (i + 1), len(replacedPodflowConfig.Steps))
			if !currentState.AuphonicProduction {
				report("auphonic", backend.StatusInProgress)
				step.Auphonic.Title = strings.ReplaceAll(step.Auphonic.Title, "{{episodeTitle}}", currentState.Metadata.Title)
				_, err := targets.StartAuphonicProduction("https://auphonic.com", step, 20)

				if err != nil {
					report("auphonic", backend.StatusFailed)
					color.Red(errorPrefix + err.Error())
					return err
				}

				currentState.AuphonicProduction = true
				if err := stateIo.Write(currentState); err != nil {
					return err
				}
				report("auphonic", backend.StatusDone)
				color.Green("  Auphonic production done")
			} else {
				report("auphonic", backend.StatusDone)
				color.Green("  Auphonic production skipped")
			}
		}
	}
	return nil
}
