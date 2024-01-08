package config_test
import (
	config "podflow/internal/configuration"
	testData "podflow/test/data/config"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("The podflow configuration", func() {
    It("can be loaded if file is present", func() {
        mockConfigurationFile := testData.ValidConfigurationFile{}
        config, err := config.Load(mockConfigurationFile)

        Expect(err).Should(BeNil())
        Expect(config).ShouldNot(BeNil())
    })

    It("returns an error if it does not exist", func() {
        mockConfigurationFile := testData.NonExistingConfigurationFile{}
        _, err := config.Load(mockConfigurationFile)

        Expect(err).ShouldNot(BeNil())
    })

    It("returns an error if path can not be determined", func() {
        mockConfigurationFile := testData.InvalidPathConfigurationFile{}
        _, err := config.Load(mockConfigurationFile)

        Expect(err).ShouldNot(BeNil())
    })

    It("returns an error if config file is not readable", func() {
        mockConfigurationFile := testData.NotReadableConfigurationFile{}
        _, err := config.Load(mockConfigurationFile)

        Expect(err).ShouldNot(BeNil())
    })

    It("replace folderName in list of files configuration", func() {
        mockConfigurationFile := testData.ValidConfigurationFile{}
        config, _ := config.LoadAndReplacePlaceholders(mockConfigurationFile)

        Expect(config).ShouldNot(BeNil())
        Expect(config.Files[0].FileName).Should(Equal("configuration.mp3"))
    })

    It("replace folderName & episodeNumber in list of files to use in a step", func() {
        mockConfigurationFile := testData.ValidConfigurationFile{}
        config, _ := config.LoadAndReplacePlaceholders(mockConfigurationFile)

        Expect(config).ShouldNot(BeNil())
        Expect(config.Steps[0].Files[0].Source).Should(Equal("1_configuration.mp3"))
        Expect(config.Steps[0].Files[0].Target).Should(Equal("1_configuration.mp3"))
    })
})
