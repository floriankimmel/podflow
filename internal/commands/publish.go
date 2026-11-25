package cmd

import (
	"fmt"
	"github.com/floriankimmel/podflow/internal/backend"
	config "github.com/floriankimmel/podflow/internal/configuration"
	"github.com/floriankimmel/podflow/internal/input"
	"github.com/floriankimmel/podflow/internal/state"
	"github.com/floriankimmel/podflow/internal/targets"
	"github.com/floriankimmel/podflow/internal/targets/wordpress"
	"path/filepath"
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
	return publish(io, stateIo, userInput, workingDir, true)
}

// publish runs the configured steps. reportSteps sends step status to the
// backend; it is off when a caller (the desktop app's run) owns the status.
func publish(
	io config.ConfigurationReaderWriter,
	stateIo state.StateReaderWriter,
	userInput input.Input,
	workingDir string,
	reportSteps bool,
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
	var reporter *backend.Reporter
	if reportSteps {
		reporter = backend.New(backendConfig.URL, backendConfig.WorkspaceKey)
	}
	episodeMetadata := backend.Metadata{
		EpisodeNumber: currentState.Metadata.EpisodeNumber,
		Title:         currentState.Metadata.Title,
		ReleaseDate:   currentState.Metadata.ReleaseDate,
	}
	report := func(step string, status string) {
		reporter.Report(episodeMetadata, step, status)
	}

	total := len(replacedPodflowConfig.Steps)
	for i := range replacedPodflowConfig.Steps {
		step := replacedPodflowConfig.Steps[i]
		metadata := currentState.Metadata
		steps := []resumableStep{
			{
				id: "ftp_delete", heading: "Delete FTP files", label: "FTP deletion",
				applies: len(step.FTP.Delete) > 0,
				done:    func(s *state.State) *bool { return &s.FTPDeleted },
				run:     func() error { return targets.FtpDelete(step) },
			},
			{
				id: "ftp_upload", heading: "FTP", label: "FTP upload",
				applies: len(step.FTP.Files) > 0,
				done:    func(s *state.State) *bool { return &s.FTPUploaded },
				run:     func() error { return targets.FtpUpload(step) },
			},
			{
				id: "download", heading: "Download", label: "Download",
				applies: len(step.Download.Files) > 0,
				done:    func(s *state.State) *bool { return &s.Downloaded },
				run:     func() error { return targets.FtpDownload(step) },
			},
			{
				id: "s3", heading: "Amazon S3", label: "S3 upload",
				applies: len(step.S3.Buckets) > 0,
				done:    func(s *state.State) *bool { return &s.S3Uploaded },
				run:     func() error { return targets.S3Upload(step.S3) },
			},
			{
				id: "wordpress", heading: "Wordpress", label: "Wordpress production",
				applies: step.Wordpress != (config.Wordpress{}),
				done:    func(s *state.State) *bool { return &s.WordpressBlogCreated },
				run:     func() error { return scheduleWordpress(step.Wordpress, metadata, stateIo) },
			},
			{
				id: "steady", heading: "SteadyHq", label: "Steady production",
				applies: step.SteadyHq != (config.SteadyHq{}),
				done:    func(s *state.State) *bool { return &s.SteadyHqCreated },
				run: func() error {
					steady := step.SteadyHq
					steady.Title = strings.ReplaceAll(steady.Title, "{{episodeTitle}}", metadata.Title)
					return targets.ScheduleSteadyHq(steady, metadata.ReleaseDate)
				},
			},
			{
				id: "auphonic", heading: "Auphonic", label: "Auphonic production",
				applies: len(step.Auphonic.Title) > 0,
				done:    func(s *state.State) *bool { return &s.AuphonicProduction },
				run: func() error {
					auphonic := step
					auphonic.Auphonic.Title = strings.ReplaceAll(auphonic.Auphonic.Title, "{{episodeTitle}}", metadata.Title)
					_, err := targets.StartAuphonicProduction("https://auphonic.com", auphonic, 20)
					return err
				},
			},
		}
		for _, resumable := range steps {
			if !resumable.applies {
				continue
			}
			fmt.Printf("\n\n[%d/%d] %s \n", i+1, total, resumable.heading)
			if err := resumable.runOnce(stateIo, report); err != nil {
				return err
			}
		}
	}
	return nil
}

// resumableStep is one publish target. Its done flag in the state file makes
// a repeated publish skip it.
type resumableStep struct {
	// id is the step name reported to the backend.
	id, heading, label string
	applies            bool
	done               func(*state.State) *bool
	run                func() error
}

func (r resumableStep) runOnce(stateIo state.StateReaderWriter, report func(step, status string)) error {
	current, err := stateIo.Read()
	if err != nil {
		return err
	}
	if *r.done(&current) {
		report(r.id, backend.StatusDone)
		color.Green("  " + r.label + " skipped")
		return nil
	}

	report(r.id, backend.StatusInProgress)
	if err := r.run(); err != nil {
		report(r.id, backend.StatusFailed)
		color.Red(errorPrefix + err.Error())
		return err
	}

	// The step may have saved progress of its own (e.g. WordPress ids).
	current, err = stateIo.Read()
	if err != nil {
		return err
	}
	*r.done(&current) = true
	if err := stateIo.Write(current); err != nil {
		return err
	}
	report(r.id, backend.StatusDone)
	color.Green("  " + r.label + " done")
	return nil
}

// scheduleWordpress schedules the website post and keeps the WordPress ids in
// the state file as they are created, so a failed run resumes.
func scheduleWordpress(cfg config.Wordpress, metadata state.Metadata, stateIo state.StateReaderWriter) error {
	post, err := wordpress.NewPost(cfg, metadata.Title, metadata.EpisodeNumber, metadata.ReleaseDate)
	if err != nil {
		return err
	}
	current, err := stateIo.Read()
	if err != nil {
		return err
	}
	ids := wordpress.IDs{
		PodloveID:       current.Wordpress.PodloveID,
		WordpressID:     current.Wordpress.WordpressID,
		FeaturedMediaID: current.Wordpress.FeaturedMediaID,
	}
	save := func(ids wordpress.IDs) error {
		current, err := stateIo.Read()
		if err != nil {
			return err
		}
		current.Wordpress.PodloveID = ids.PodloveID
		current.Wordpress.WordpressID = ids.WordpressID
		current.Wordpress.FeaturedMediaID = ids.FeaturedMediaID
		return stateIo.Write(current)
	}
	_, err = wordpress.ScheduleEpisode(wordpress.Site{Server: cfg.Server, APIKey: cfg.APIKey}, post, ids, save)
	return err
}
