package state

import (
	"fmt"
	"os"
	"path/filepath"
	config "podflow/internal/configuration"
	"podflow/internal/input"
	"time"
)

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

func EnterChapterMark(file StateFile) (ChapterMark, error) {
	fmt.Print("Enter chapter name: ")
	mark := AddChapterMark(input.Stdin{})
	return saveChapterMark(file, mark)
}

func StartEpisode(file StateFile) (ChapterMark, error) {
	mark := AddChapterMark(StringInput{Input: "Start"})
	return saveChapterMark(file, mark)
}

func EndEpisode(file StateFile) (ChapterMark, error) {
	mark := AddChapterMark(StringInput{Input: "End"})
	return saveChapterMark(file, mark)
}

func saveChapterMark(file StateFile, mark ChapterMark) (ChapterMark, error) {
	state, err := file.Read()

	if err != nil {
		return mark, err
	}

	for _, existingMark := range state.ChapterMarks {
		if existingMark.Name == mark.Name {
			return existingMark, nil
		}
	}

	state.ChapterMarks = append(state.ChapterMarks, mark)

	if err := file.Write(state); err != nil {
		return mark, err
	}

	return mark, nil
}

func AddChapterMark(input input.Input) ChapterMark {
	chapterName := input.Text("Chapter: ")

	chapterMark := ChapterMark{
		Name: chapterName,
		Time: time.Now(),
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
	chapterFilePath := filepath.Join(path, "export_"+filepath.Base(path)+".chapters.txt")
	file, err := os.Create(chapterFilePath)
	if err != nil {
		return err
	}

	defer file.Close()

	for i := 1; i < len(chapters); i++ {
		diff := chapters[i].Time.Sub(chapters[i-1].Time)

		record := fmt.Sprintf("%s %s\n", formatDuration(diff), chapters[i].Name)

		_, err := file.WriteString(record)
		if err != nil {
			return err
		}
	}

	return nil
}
