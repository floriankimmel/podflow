package wordpress

import (
	"encoding/json"
	"fmt"
	"os"
	config "podflow/internal/configuration"
	"podflow/internal/state"
)

func ScheduleEpisode(
	step config.Step,
	stateIo state.StateReaderWriter,
	title string,
	currentEpisodeNumber string,
	scheduledDate string,
) (Episode, error) {
	fmt.Printf(" Schedule blogpost '%s' for %s \n", title, scheduledDate)
	wordpressConfig := step.Wordpress

	currentState, err := stateIo.Read()

	if err != nil {
		return Episode{}, err
	}

	episode := Episode{}

	if currentState.Wordpress.WordpressID == "" {
		fmt.Println(" Initiating episode")
		episode.create(wordpressConfig.Server, wordpressConfig.APIKey)

		currentState.Wordpress.PodloveID = episode.PodloveID
		currentState.Wordpress.WordpressID = episode.WordpressID

		if err := stateIo.Write(currentState); err != nil {
			return Episode{}, err
		}

	} else {
		fmt.Println("Episode already initiated")

		episode.APIKey = wordpressConfig.APIKey
		episode.Server = wordpressConfig.Server
		episode.WordpressID = currentState.Wordpress.WordpressID
		episode.PodloveID = currentState.Wordpress.PodloveID
	}

	fullTitle := fmt.Sprintf("LEP#%s - %s", currentEpisodeNumber, title)

	fmt.Println(" Setting title")
	if err := episode.setTitle(fullTitle); err != nil {
		return Episode{}, err
	}

	fmt.Println(" Setting URL")
	if err := episode.setURL(currentEpisodeNumber); err != nil {
		return Episode{}, err
	}

	fmt.Println(" Setting slug")
	if err := episode.setSlug(wordpressConfig.Episode); err != nil {
		return Episode{}, err
	}

	fmt.Println(" Setting episode number")
	if err := episode.setEpisodeNumber(currentEpisodeNumber); err != nil {
		return Episode{}, err
	}

	if _, err := os.Stat(wordpressConfig.ShowNotes); os.IsExist(err) {
		fmt.Println(" Setting show notes")
		if err := episode.setContent(wordpressConfig.ShowNotes); err != nil {
			return Episode{}, err
		}
	}

	fmt.Println(" Setting scheduled date")
	if err := episode.schedulePostFor(scheduledDate); err != nil {
		return Episode{}, err
	}

	image := Image{
		title: title,
		path:  wordpressConfig.Image,
	}

	if currentState.Wordpress.FeaturedMediaID == "" {
		fmt.Println(" Uploading featured image")

		if err := image.uploadTo(wordpressConfig.Server, wordpressConfig.APIKey); err != nil {
			return Episode{}, err
		}
		currentState.Wordpress.FeaturedMediaID = image.ID.String()
		if err := stateIo.Write(currentState); err != nil {
			return Episode{}, err
		}
	} else {
		fmt.Println(" Featured image already uploaded")
		image.ID = json.Number(currentState.Wordpress.FeaturedMediaID)
	}

	fmt.Printf("\n")
	fmt.Println(" Set featured image")
	if err := episode.setFeaturedMedia(image); err != nil {
		return Episode{}, err
	}

	fmt.Println(" Setting Assets")
	if err := episode.enableAsset("2"); err != nil {
		return Episode{}, err
	}

	if err := episode.enableAsset("3"); err != nil {
		return Episode{}, err
	}

	fmt.Println(" Adding Chapter markers")
	if err := episode.addChapters(wordpressConfig.Chapter); err != nil {
		return Episode{}, err
	}

	return episode, nil
}
