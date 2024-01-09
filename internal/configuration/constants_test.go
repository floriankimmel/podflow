package config_test

import (
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"

	"podflow/internal/configuration"
)

var _ = Describe("Getting constant", func() {
    It("episode slug should work", func() {
        slug := config.EpisodeSlug(config.Dir())
        Expect(slug).Should(Equal("configuration.m4a"))
    })
    It("dir should work", func() {
        slug := config.Dir()
        Expect(slug).Should(ContainSubstring("/configuration"))
    })

})
