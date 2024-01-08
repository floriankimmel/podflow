package config_test
import (
	config "podflow/internal/configuration"
	testData "podflow/test/data/config"

	ginkgo "github.com/onsi/ginkgo/v2"
	"github.com/onsi/gomega"
)

var _ = ginkgo.Describe("The podflow configuration", func() {
    ginkgo.It("can be loaded if file is present", func() {
        mockConfigurationFile := testData.ValidConfigurationFile{}
        config, err := config.Load(mockConfigurationFile)

        gomega.Expect(err).Should(gomega.BeNil())
        gomega.Expect(config).ShouldNot(gomega.BeNil())
    })

    ginkgo.It("returns an error if it does not exist", func() {
        mockConfigurationFile := testData.NonExistingConfigurationFile{}
        _, err := config.Load(mockConfigurationFile)

        gomega.Expect(err).Should(gomega.BeNil())
    })

})
