package config_test

import (
	"os"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"

	config "podflow/internal/configuration"
)

var _ = Describe("Getting the podflow file", func() {
	It("standard name if no env variable is set", func() {
		Expect(config.GetConfigFileName()).Should(Equal("config.yml"))
	})

	It("name of the env variable if env variable is set", func() {
		os.Setenv("PODFLOW_CONFIG_FILE", "podflow.yml")
		Expect(config.GetConfigFileName()).Should(Equal("podflow.yml"))
	})
})
