package state_test

import (
	"os"
	"podflow/internal/state"
	"time"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

type ChapterStateFile struct{}

func (file ChapterStateFile) Read() (state.State, error) {
	return state.State{}, nil
}

func (file ChapterStateFile) Write(state state.State) error {
	return nil
}

func (file ChapterStateFile) GetStateFilePath() string {
	return ""
}

var _ = AfterEach(func() {
	os.Remove(stateReaderWriter.GetStateFilePath())
})

var _ = Describe("A chapter mark can be", func() {
	It("set at the start of the recording", func() {
		mark, err := state.StartEpisode(ChapterStateFile{})

		Expect(err).Should(BeNil())
		Expect(mark).ShouldNot(BeNil())
		Expect(mark.Name).Should(Equal("Start"))
	})

	It("set at the start of the recording and returns old value when calling it twice", func() {
		mark, err := state.StartEpisode(ChapterStateFile{})

		Expect(err).Should(BeNil())
		Expect(mark).ShouldNot(BeNil())
		Expect(mark.Name).Should(Equal("Start"))

		mark2, err := state.StartEpisode(ChapterStateFile{})
		Expect(err).Should(BeNil())
		Expect(mark2.Time.Round(time.Second)).Should(Equal(mark.Time.Round(time.Second)))
	})

	It("set at the end of the recording", func() {
		mark, err := state.EndEpisode(ChapterStateFile{})

		Expect(err).Should(BeNil())
		Expect(mark).ShouldNot(BeNil())
		Expect(mark.Name).Should(Equal("End"))
	})

	It("added at anytime", func() {
		mark, err := state.EnterChapterMark(ChapterStateFile{}, state.StringInput{Input: "Test"})

		Expect(err).Should(BeNil())
		Expect(mark).ShouldNot(BeNil())
		Expect(mark.Name).Should(Equal("Test"))
	})

})
