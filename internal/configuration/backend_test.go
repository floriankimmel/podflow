package config_test

import (
	"os"
	config "podflow/internal/configuration"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("ResolvedBackend", func() {
	AfterEach(func() {
		os.Unsetenv("PODFLOW_BACKEND_URL")
		os.Unsetenv("PODFLOW_WORKSPACE_KEY")
		os.Unsetenv("TEST_WS_KEY")
	})

	It("is empty (disabled) when nothing is configured", func() {
		cfg := config.Configuration{}
		backend := cfg.ResolvedBackend()
		Expect(backend.URL).To(BeEmpty())
		Expect(backend.WorkspaceKey).To(BeEmpty())
	})

	It("loads url and key from the config file values", func() {
		cfg := config.Configuration{Backend: config.Backend{URL: "https://api.example.com", WorkspaceKey: "abc"}}
		backend := cfg.ResolvedBackend()
		Expect(backend.URL).To(Equal("https://api.example.com"))
		Expect(backend.WorkspaceKey).To(Equal("abc"))
	})

	It("lets environment variables override the config file", func() {
		os.Setenv("PODFLOW_BACKEND_URL", "https://env.example.com")
		os.Setenv("PODFLOW_WORKSPACE_KEY", "env-key")
		cfg := config.Configuration{Backend: config.Backend{URL: "https://file.example.com", WorkspaceKey: "file-key"}}
		backend := cfg.ResolvedBackend()
		Expect(backend.URL).To(Equal("https://env.example.com"))
		Expect(backend.WorkspaceKey).To(Equal("env-key"))
	})

	It("resolves {{env.*}} references in the key", func() {
		os.Setenv("TEST_WS_KEY", "resolved-secret")
		cfg := config.Configuration{Backend: config.Backend{URL: "https://x", WorkspaceKey: "{{env.TEST_WS_KEY}}"}}
		Expect(cfg.ResolvedBackend().WorkspaceKey).To(Equal("resolved-secret"))
	})
})
