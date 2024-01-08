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
        releaseInformation := config.GetReleaseInformation(mockConfigurationFile)

        Expect(releaseInformation).ShouldNot(BeNil())
        Expect(releaseInformation.EpisodeNumber).Should(Equal(1))
    })

    It("should return the next release date", func() {
        mockConfigurationFile := testData.ValidConfigurationFile{}
        releaseInformation := config.GetReleaseInformation(mockConfigurationFile)
        layout := "2006-01-02 15:04:05"

        parsedTime, _ := time.Parse(layout, releaseInformation.NextReleaseDate)


        Expect(releaseInformation).ShouldNot(BeNil())
        Expect(parsedTime.Weekday().String()).Should(Equal("Friday"))
        Expect(parsedTime.Hour()).Should(Equal(9))
        Expect(parsedTime.Minute()).Should(Equal(0))
        Expect(parsedTime.Second()).Should(Equal(0))
    })
})
