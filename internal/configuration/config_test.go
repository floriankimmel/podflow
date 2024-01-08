package config_test

import (
	ginkgo "github.com/onsi/ginkgo/v2"
	"github.com/onsi/gomega"

	"podflow/internal/configuration"
)

type MockConfigurationFile struct {
}

func (file MockConfigurationFile) Read(path string) (config.Configuration, error) {
    return config.Configuration{}, nil
}

func (file MockConfigurationFile) Path() (string, error) {
    return "", nil
}
func (file MockConfigurationFile) Write(config config.Configuration) error {
    return nil
}

func (file MockConfigurationFile) IsNotExist(path string) bool {
    return false
}

var mockConfigurationFile = MockConfigurationFile{}

var _ = ginkgo.BeforeEach(func() {
    mockConfigurationFile = MockConfigurationFile{}
})

var _ = ginkgo.Describe("The podflow configuration", func() {
    ginkgo.It("can be loaded if file is present", func() {
        config, err := config.Load(mockConfigurationFile)

        gomega.Expect(err).Should(gomega.BeNil())
        gomega.Expect(config).ShouldNot(gomega.BeNil())
    })

})
