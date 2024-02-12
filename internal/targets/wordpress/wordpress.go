package wordpress

import (
	"fmt"
	config "podflow/internal/configuration"
)



func ScheduleEpisode(
    step config.Step,
    title string,
    currentEpisodeNumber string,
    scheduledDate string,
) (Episode, error) {
    fmt.Printf(" Schedule blogpost '%s' for %s \n", title, scheduledDate)
    wordpressConfig := step.Wordpress

    fmt.Println(" Initiating episode")
    episode := Episode{}
    episode.create(wordpressConfig.Server, wordpressConfig.ApiKey)

    fullTitle := fmt.Sprintf("LEP#%s - %s", currentEpisodeNumber, title)

    fmt.Println(" Setting title")
    if err := episode.setTitle(fullTitle); err != nil {
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

    fmt.Println(" Setting show notes")
    if err := episode.setContent(wordpressConfig.ShowNotes); err != nil {
        return Episode{}, err
    }

    fmt.Println(" Setting scheduled date")
    if err := episode.schedulePostFor(scheduledDate); err != nil {
        return Episode{}, err
    }

    fmt.Println(" Setting featured image")
    image := Image{
        title: title,
        path:  wordpressConfig.Image,
    }

    if err := image.uploadTo(wordpressConfig.Server, wordpressConfig.ApiKey); err != nil {
        return Episode{}, err
    }

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




