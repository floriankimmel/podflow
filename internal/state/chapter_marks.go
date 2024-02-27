package state

import (
	"fmt"
	"os"
	"path/filepath"
	config "podflow/internal/configuration"
	"podflow/internal/input"
	"time"
)

const pauseStart = "PauseStart"
const pauseEnd = "PauseEnd"

type StringInput struct {
	Input string
}

func (input StringInput) Text(prompt string) string {
	return input.Input
}

type ChapterMark struct {
	Name string    `yaml:"name"`
	Time time.Time `yaml:"time"`
}

func EnterChapterMark(file StateReaderWriter, input input.Input) (ChapterMark, error) {
	fmt.Print("Enter chapter name: ")
	mark := AddChapterMark(input)
	return saveChapterMark(file, mark)
}

func StartEpisode(file StateReaderWriter) (ChapterMark, error) {
	mark := AddChapterMark(StringInput{Input: "Start"})
	return saveChapterMark(file, mark)
}

func EndEpisode(file StateReaderWriter) (ChapterMark, error) {
	mark := AddChapterMark(StringInput{Input: "End"})
	return saveChapterMark(file, mark)
}

func TogglePauseEpisode(file StateReaderWriter) (ChapterMark, error) {
	state, err := file.Read()

	if err != nil {
		return ChapterMark{}, err
	}

	input := StringInput{Input: pauseStart}

	if len(state.ChapterMarks) > 0 {
		lastMark := state.ChapterMarks[len(state.ChapterMarks)-1]

		if lastMark.Name == pauseStart {
			input = StringInput{Input: pauseEnd}
		}
	}

	mark := AddChapterMark(input)
	return saveChapterMark(file, mark)
}

func saveChapterMark(file StateReaderWriter, mark ChapterMark) (ChapterMark, error) {
	state, err := file.Read()

	if err != nil {
		return mark, err
	}

	if mark.Name != pauseStart && mark.Name != pauseEnd {
		for _, existingMark := range state.ChapterMarks {
			if existingMark.Name == mark.Name {
				return existingMark, nil
			}
		}
	}

	state.ChapterMarks = append(state.ChapterMarks, mark)

	if err := file.Write(state); err != nil {
		return mark, err
	}

	return mark, nil
}

func AddChapterMark(input input.Input) ChapterMark {
	time := time.Now()
	chapterName := input.Text("Chapter: ")

	chapterMark := ChapterMark{
		Name: chapterName,
		Time: time,
	}

	return chapterMark
}
func formatDuration(d time.Duration) string {
	d = d.Round(time.Millisecond)
	h := d / time.Hour
	d -= h * time.Hour
	m := d / time.Minute
	d -= m * time.Minute
	s := d / time.Second
	d -= s * time.Second
	ms := d / time.Millisecond

	return fmt.Sprintf("%02d:%02d:%02d.%03d", h, m, s, ms)
}

func Export(stateFile StateFile) error {
	state, err := stateFile.Read()

	if err != nil {
		return err
	}

	chapters := state.ChapterMarks

	path := config.Dir()
	chapterFilePath := filepath.Join(path, filepath.Base(path)+".chapters.txt")
	file, err := os.Create(chapterFilePath)
	if err != nil {
		return err
	}

	defer file.Close()

	start := chapters[0].Time
	pauses := []time.Duration{}

	for i := 1; i < len(chapters); i++ {
		if chapters[i].Name == pauseStart {
			pauses = append(pauses, chapters[i+1].Time.Sub(chapters[i].Time))
			i++
			continue
		}

		diff := chapters[i].Time.Sub(start)

		for _, pause := range pauses {
			diff -= pause
		}

		record := fmt.Sprintf("%s %s\n", formatDuration(diff), chapters[i].Name)

		_, err := file.WriteString(record)
		if err != nil {
			return err
		}
	}

	return nil
}
