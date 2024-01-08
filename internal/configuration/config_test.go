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

})
