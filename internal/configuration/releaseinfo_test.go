package config_test

import (
	config "podflow/internal/configuration"
	testData "podflow/test/data/config"
	"time"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("The podflow release information", func() {
    It("should return the current episode number", func() {
        mockConfigurationFile := testData.ValidConfigurationFile{}
        releaseInformation := config.GetReleaseInformation(mockConfigurationFile, time.Now())

        Expect(releaseInformation).ShouldNot(BeNil())
        Expect(releaseInformation.EpisodeNumber).Should(Equal("1"))
    })

    It("should return the next release date if today is tuesday", func() {
        mockConfigurationFile := testData.ValidConfigurationFile{}
        today := time.Date(2024, 1, 9, 9, 0, 0, 0, time.UTC)
        releaseInformation := config.GetReleaseInformation(mockConfigurationFile, today)
        layout := "2006-01-02 15:04:05"

        parsedTime, _ := time.Parse(layout, releaseInformation.NextReleaseDate)


        Expect(today.Weekday().String()).Should(Equal("Tuesday"))
        Expect(releaseInformation).ShouldNot(BeNil())
        Expect(parsedTime.Weekday().String()).Should(Equal("Friday"))
        Expect(parsedTime.Hour()).Should(Equal(9))
        Expect(parsedTime.Minute()).Should(Equal(0))
        Expect(parsedTime.Second()).Should(Equal(0))
    })

    It("should return the next release date if today is sunday", func() {
        mockConfigurationFile := testData.ValidConfigurationFile{}
        today := time.Date(2024, 1, 14, 9, 0, 0, 0, time.UTC)
        releaseInformation := config.GetReleaseInformation(mockConfigurationFile, today)
        layout := "2006-01-02 15:04:05"

        parsedTime, _ := time.Parse(layout, releaseInformation.NextReleaseDate)


        Expect(today.Weekday().String()).Should(Equal("Sunday"))
        Expect(releaseInformation).ShouldNot(BeNil())
        Expect(parsedTime.Weekday().String()).Should(Equal("Friday"))
        Expect(parsedTime.Hour()).Should(Equal(9))
        Expect(parsedTime.Minute()).Should(Equal(0))
        Expect(parsedTime.Second()).Should(Equal(0))
    })

    It("should return the next release date if today is friday", func() {
        mockConfigurationFile := testData.ValidConfigurationFile{}
        today := time.Date(2024, 1, 12, 9, 0, 0, 0, time.UTC)
        releaseInformation := config.GetReleaseInformation(mockConfigurationFile, today)
        layout := "2006-01-02 15:04:05"

        parsedTime, _ := time.Parse(layout, releaseInformation.NextReleaseDate)


        Expect(today.Weekday().String()).Should(Equal("Friday"))
        Expect(releaseInformation).ShouldNot(BeNil())
        Expect(parsedTime.Weekday().String()).Should(Equal("Friday"))
        Expect(parsedTime.Hour()).Should(Equal(9))
        Expect(parsedTime.Minute()).Should(Equal(0))
        Expect(parsedTime.Second()).Should(Equal(0))
    })
})
