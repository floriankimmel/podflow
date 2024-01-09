package cmd_test

import (
	"os"
	"path/filepath"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"

	cmd "podflow/internal/commands"
	config "podflow/internal/configuration"
	testData "podflow/test/data/config"
)

var workingDir = filepath.Join(os.TempDir(), "podflow")

var _ = Describe("Running the check command", func() {
    It("will detect that required file is available", func() {
        if err := os.MkdirAll(workingDir, os.ModePerm); err != nil {
            panic(err)
        }
        configFilePath := filepath.Join(workingDir, "podflow.yml")
        tempFile, _ := os.Create(configFilePath)

        filePath := filepath.Join(workingDir, "podflow.mp3")
        file, _ := os.Create(filePath)

        defer os.Remove(tempFile.Name())
        defer os.Remove(file.Name())

        io := testData.TempConfigurationFile{}
        if err := io.Write(config.Configuration{
            Files: []config.File{
                {
                    Name: "Podflow",
                    FileName: "{{folderName}}.mp3",
                    Required: true,
                },
            },
        }); err != nil {
            panic(err)
        }
        err := cmd.Check(io, workingDir)


        Expect(err).Should(BeNil())
    })

    It("will detect that file is not empty", func() {
        if err := os.MkdirAll(workingDir, os.ModePerm); err != nil {
            panic(err)
        }
        configFilePath := filepath.Join(workingDir, "podflow.yml")
        tempFile, _ := os.Create(configFilePath)

        filePath := filepath.Join(workingDir, "podflow.md")
        file, _ := os.Create(filePath)

        if err := os.WriteFile(filePath, []byte("test"), 0644); err != nil {
            panic(err)
        }

        defer os.Remove(tempFile.Name())
        defer os.Remove(file.Name())

        io := testData.TempConfigurationFile{}
        if err := io.Write(config.Configuration{
            Files: []config.File{
                {
                    Name: "Podflow",
                    FileName: "{{folderName}}.md",
                    NotEmpty: true,
                },
            },
        }); err != nil {
            panic(err)
        }
        err := cmd.Check(io, workingDir)

        Expect(err).Should(BeNil())
    })

    It("will detect that file has not umlaute", func() {
        if err := os.MkdirAll(workingDir, os.ModePerm); err != nil {
            panic(err)
        }
        configFilePath := filepath.Join(workingDir, "podflow.yml")
        tempFile, _ := os.Create(configFilePath)

        filePath := filepath.Join(workingDir, "podflow.md")
        file, _ := os.Create(filePath)

        defer os.Remove(tempFile.Name())
        defer os.Remove(file.Name())

        if err := os.WriteFile(filePath, []byte("test"), 0644); err != nil {
            panic(err)
        }

        io := testData.TempConfigurationFile{}
        if err := io.Write(config.Configuration{
            Files: []config.File{
                {
                    Name: "Podflow",
                    FileName: "{{folderName}}.md",
                    UmlauteNotAllowed: true,
                },
            },
        }); err != nil {
            panic(err)
        }
        err := cmd.Check(io, workingDir)

        Expect(err).Should(BeNil())
    })

    It("will detect that file has umlaute and return with error", func() {
        if err := os.MkdirAll(workingDir, os.ModePerm); err != nil {
            panic(err)
        }
        configFilePath := filepath.Join(workingDir, "podflow.yml")
        tempFile, _ := os.Create(configFilePath)

        filePath := filepath.Join(workingDir, "ä.md")
        file, _ := os.Create(filePath)

        if err := os.WriteFile(filePath, []byte("test"), 0644); err != nil {
            panic(err)
        }

        defer os.Remove(tempFile.Name())
        defer os.Remove(file.Name())

        io := testData.TempConfigurationFile{}
        if err := io.Write(config.Configuration{
            Files: []config.File{
                {
                    Name: "Podflow",
                    FileName: "ä.md",
                    UmlauteNotAllowed: true,
                },
            },
        }); err != nil {
            panic(err)
        }

        err := cmd.Check(io, workingDir)

        Expect(err).ShouldNot(BeNil())

    })
})
