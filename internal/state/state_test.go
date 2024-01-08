package state_test

import (
	"os"
	"podflow/internal/state"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)


var stateReaderWriter = state.StateFile{}

var _ = AfterEach(func() {
    os.Remove(stateReaderWriter.GetStateFilePath())
})

var _ = Describe("The state of the current podflow", func() {
    It("can be read even though it does not exist yet", func() {
        state, err := stateReaderWriter.Read()

        Expect(err).Should(BeNil())
        Expect(state).ShouldNot(BeNil())
    })

    It("can be writte", func() {
        state := state.State{
            Metadata: state.Metadata{
                EpisodeNumber: 1,
                ReleaseDate: "2021-01-01 09:00:00",
                Title: "Podflow",
            },
            FTPUploaded: false,
        }
        err := stateReaderWriter.Write(state)
        Expect(err).Should(BeNil())

        stateFile, _ := stateReaderWriter.Read()

        Expect(stateFile.FTPUploaded).Should(Equal(false))
        Expect(stateFile.Metadata.EpisodeNumber).Should(Equal(1))
    })

})
