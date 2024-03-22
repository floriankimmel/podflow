package cmd_test

import (
	"os"
	"path/filepath"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"

	cmd "podflow/internal/commands"
	config "podflow/internal/configuration"
	state "podflow/internal/state"
	testData "podflow/test/testdata"
)

type MockInput struct{}

func (input MockInput) Text(prompt string) string {
	return "Title"
}

var testConfig = config.Configuration{
	CurrentEpisode: "7",
	Files: []config.EpisodeFile{
		{
			Name:     "Podflow",
			FileName: "{{folderName}}.mp3",
			Required: true,
		},
	},
}

var _ = Describe("Running the publish command", func() {

	It("run successfully and publish an episode", func() {
		if err := os.MkdirAll(workingDir, os.ModePerm); err != nil {
			panic(err)
		}
		configFilePath := filepath.Join(workingDir, "podflow.yml")
		tempFile, _ := os.Create(configFilePath)

		filePath := filepath.Join(workingDir, "podflow.mp3")
		file, _ := os.Create(filePath)

		stateFilePath := filepath.Join(workingDir, "podflow.state.yml")
		stateFile, _ := os.Create(stateFilePath)

		defer os.Remove(tempFile.Name())
		defer os.Remove(file.Name())
		defer os.Remove(stateFile.Name())

		io := testData.TempConfigurationFile{}
		if err := io.Write(testConfig); err != nil {
			panic(err)
		}

		stateIo := testData.TempStateFile{}
		err := cmd.Publish(io, stateIo, MockInput{}, workingDir)
		Expect(err).Should(BeNil())

		state, _ := stateIo.Read()
		Expect(state.Metadata.Title).Should(Equal("Title"))
		Expect(state.Metadata.EpisodeNumber).Should(Equal("8"))
	})

	It("do not recalculate metadata if state is persisted", func() {
		if err := os.MkdirAll(workingDir, os.ModePerm); err != nil {
			panic(err)
		}
		configFilePath := filepath.Join(workingDir, "podflow.yml")
		tempFile, _ := os.Create(configFilePath)

		filePath := filepath.Join(workingDir, "podflow.mp3")
		file, _ := os.Create(filePath)

		stateFilePath := filepath.Join(workingDir, "podflow.state.yml")
		stateFile, _ := os.Create(stateFilePath)

		defer os.Remove(tempFile.Name())
		defer os.Remove(file.Name())
		defer os.Remove(stateFile.Name())
		io := testData.TempConfigurationFile{}
		if err := io.Write(testConfig); err != nil {
			panic(err)
		}

		stateIo := testData.TempStateFile{}

		if err := stateIo.Write(state.State{
			Metadata: state.Metadata{
				Title:         "Persisted Title",
				EpisodeNumber: "9",
			},
		}); err != nil {
			panic(err)
		}
		err := cmd.Publish(io, stateIo, MockInput{}, workingDir)
		Expect(err).Should(BeNil())

		state, _ := stateIo.Read()
		Expect(state.Metadata.Title).Should(Equal("Persisted Title"))
		Expect(state.Metadata.EpisodeNumber).Should(Equal("9"))
	})
})
