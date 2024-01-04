package config

import (
	"time"
)

type Metadata struct {
    NextReleaseDate string
    EpisodeNumber int
}

func GetMetadata() Metadata {
    config, _ := Load()
    metadata := Metadata{
        NextReleaseDate: NextReleaseDate(config.ReleaseDay, config.ReleaseTime),
        EpisodeNumber: config.CurrentEpisode,
    }
    return metadata

}

func NextReleaseDate (releaseDay string, releaseTime string) string {
    today := time.Now()
    desiredWeekday := convertStringToWeekday(releaseDay) 

	if today.Weekday() >= desiredWeekday { 
		today = today.AddDate(0, 0, 7)
	}
    daysUntil := int(desiredWeekday - today.Weekday())

    desiredDay := today.AddDate(0, 0, daysUntil)
    return desiredDay.Format("2006-01-02") + " " + releaseTime
}

func convertStringToWeekday(wochentag string) time.Weekday {
    switch wochentag {
    case "Monday":
        return time.Monday
    case "Tuesday":
        return time.Tuesday
    case "Wednesday":
        return time.Wednesday
    case "Thursday":
        return time.Thursday
    case "Friday":
        return time.Friday
    case "Saturday":
        return time.Saturday
    case "Sunday":
        return time.Sunday
    default:
        return time.Sunday 
    }
}
