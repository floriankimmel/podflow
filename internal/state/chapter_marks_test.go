package state_test

import (
	"podflow/internal/state"
	"time"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

type ChapterStateFile struct{}

var testState = state.State{}

func (file ChapterStateFile) Read() (state.State, error) {
	return testState, nil
}

func (file ChapterStateFile) Write(state state.State) error {
	testState = state
	return nil
}

func (file ChapterStateFile) GetStateFilePath() string {
	return ""
}

var _ = AfterEach(func() {
	testState = state.State{}
})

var _ = Describe("The time of", func() {
	It("the episode start can be stored", func() {
		mark, err := state.StartEpisode(ChapterStateFile{})

		Expect(err).Should(BeNil())
		Expect(mark).ShouldNot(BeNil())
		Expect(mark.Name).Should(Equal("Start"))
	})

	It("the episode start can only be stored once", func() {
		mark, err := state.StartEpisode(ChapterStateFile{})

		Expect(err).Should(BeNil())
		Expect(mark).ShouldNot(BeNil())
		Expect(mark.Name).Should(Equal("Start"))

		mark2, err := state.StartEpisode(ChapterStateFile{})
		Expect(err).Should(BeNil())
		Expect(mark2.Time.Round(time.Second)).Should(Equal(mark.Time.Round(time.Second)))
	})
	It("a pause can be storeds so that it will be subtracted from the chapter mark export", func() {
		start, err := state.TogglePauseEpisode(ChapterStateFile{})

		Expect(err).Should(BeNil())
		Expect(start).ShouldNot(BeNil())
		Expect(start.Name).Should(Equal("PauseStart"))

		end, err := state.TogglePauseEpisode(ChapterStateFile{})
		Expect(err).Should(BeNil())
		Expect(end.Name).Should(Equal("PauseEnd"))
		Expect(end.Time.Round(time.Second)).Should(Equal(start.Time.Round(time.Second)))
	})

	It("a pause can be stored multiple times", func() {
		start, err := state.TogglePauseEpisode(ChapterStateFile{})
		Expect(start.Name).Should(Equal("PauseStart"))
		Expect(err).Should(BeNil())

		_, err = state.TogglePauseEpisode(ChapterStateFile{})
		Expect(err).Should(BeNil())

		time.Sleep(1 * time.Second)
		secondStart, err := state.TogglePauseEpisode(ChapterStateFile{})
		Expect(err).Should(BeNil())
		Expect(secondStart.Name).Should(Equal("PauseStart"))

		Expect(secondStart.Time.Round(time.Second)).ShouldNot(Equal(start.Time.Round(time.Second)))
	})

	It("the end of the recording can be stored", func() {
		mark, err := state.EndEpisode(ChapterStateFile{})

		Expect(err).Should(BeNil())
		Expect(mark).ShouldNot(BeNil())
		Expect(mark.Name).Should(Equal("End"))
	})

	It("a chapter can be stored", func() {
		mark, err := state.EnterChapterMark(ChapterStateFile{}, state.StringInput{Input: "Test"})

		Expect(err).Should(BeNil())
		Expect(mark).ShouldNot(BeNil())
		Expect(mark.Name).Should(Equal("Test"))
	})

})
