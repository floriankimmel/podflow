package config_test

import (
	"os"
	"path/filepath"
	config "podflow/internal/configuration"
	testData "podflow/test/data/config"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var workingDir = filepath.Join(os.TempDir(), "podflow")

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
        config, _ := config.LoadAndReplacePlaceholders(mockConfigurationFile, config.Dir())

        Expect(config).ShouldNot(BeNil())
        Expect(config.Files[0].FileName).Should(Equal("configuration.mp3"))
    })

    It("replace folderName & episodeNumber in list of files to use in a step", func() {
        mockConfigurationFile := testData.ValidConfigurationFile{}
        config, _ := config.LoadAndReplacePlaceholders(mockConfigurationFile, config.Dir())

        Expect(config).ShouldNot(BeNil())
        Expect(config.Steps[0].Files[0].Source).Should(Equal("1_configuration.mp3"))
        Expect(config.Steps[0].Files[0].Target).Should(Equal("1_configuration.mp3"))
    })

    It("can be written and read successfully", func() {
        if err := os.MkdirAll(workingDir, os.ModePerm); err != nil {
            panic(err)
        }
        configFilePath := filepath.Join(workingDir, "podflow.yml")
        tempFile, _ := os.Create(configFilePath)

        defer os.Remove(tempFile.Name())

        io := testData.TempConfigurationFile{}
        if err := io.Write(config.Configuration{
            CurrentEpisode: 7,
        }); err != nil {
            panic(err)
        }
        config, _ := io.Read(configFilePath)
        Expect(config.CurrentEpisode).Should(Equal(7))

    })

    It("can be loaded successfully", func() {
        if err := os.MkdirAll(workingDir, os.ModePerm); err != nil {
            panic(err)
        }
        configFilePath := filepath.Join(workingDir, "podflow.yml")
        tempFile, _ := os.Create(configFilePath)

        defer os.Remove(tempFile.Name())

        io := testData.TempConfigurationFile{}
        if err := io.Write(config.Configuration{
            CurrentEpisode: 7,
        }); err != nil {
            panic(err)
        }
        config, _ := config.Load(io)
        Expect(config.CurrentEpisode).Should(Equal(7))

    })

    It("is not available", func() {
        if err := os.MkdirAll(workingDir, os.ModePerm); err != nil {
            panic(err)
        }
        configFilePath := filepath.Join(workingDir, "podflow.yml")
        os.Remove(configFilePath)

        io := testData.TempConfigurationFile{}
        _, err := config.Load(io)
        Expect(err).ShouldNot(BeNil())
    })

    It("can be loaded and replaced successfully", func() {
        if err := os.MkdirAll(workingDir, os.ModePerm); err != nil {
            panic(err)
        }
        configFilePath := filepath.Join(workingDir, "podflow.yml")
        tempFile, _ := os.Create(configFilePath)

        defer os.Remove(tempFile.Name())

        io := testData.TempConfigurationFile{}
        if err := io.Write(config.Configuration{
            CurrentEpisode: 7,
            Files: []config.File{
                {
                    Name: "Podflow",
                    FileName: "{{folderName}}.mp3",
                    Required: true,
                },
            },
            Steps: []config.Step{
                {
                    Files: []config.FileUpload{
                        {
                            Source: "{{episodeNumber}}_{{folderName}}.mp3",
                            Target: "{{episodeNumber}}_{{folderName}}.mp3",
                        },
                    },
                },
            },
        }); err != nil {
            panic(err)
        }
        config, _ := config.LoadAndReplacePlaceholders(io, workingDir)
        Expect(config.Files[0].FileName).Should(Equal("podflow.mp3"))
        Expect(config.Steps[0].Files[0].Source).Should(Equal("7_podflow.mp3"))
        Expect(config.Steps[0].Files[0].Target).Should(Equal("7_podflow.mp3"))

    })
})
