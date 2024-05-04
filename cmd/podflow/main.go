package main

import (
	"fmt"
	"log"
	"os"
	"path/filepath"
	"time"

	cmd "podflow/internal/commands"
	config "podflow/internal/configuration"
	input "podflow/internal/input"
	"podflow/internal/state"

	"github.com/urfave/cli/v2"
)

func init() {
	cli.VersionPrinter = func(cCtx *cli.Context) {
		fmt.Printf("Podflow %s \n", cCtx.App.Version)
	}
}

func main() {

	dir, _ := os.Getwd()
	folderName := filepath.Base(dir)
	logFile, err := os.OpenFile(filepath.Join(dir, folderName+".log"), os.O_RDWR|os.O_CREATE|os.O_APPEND, 0666)

	if err != nil {
		log.Fatalf("Error opening file: %v", err)
	}

	defer logFile.Close()

	log.SetFlags(log.LstdFlags | log.Lshortfile)
	log.SetOutput(logFile)

	app := &cli.App{
		Name:     "podflow",
		Usage:    " A CLI tool for automating everything related to your podcast",
		Version:  "0.0.1",
		Compiled: time.Now(),
		Authors: []*cli.Author{
			{
				Name:  "Florian Kimmel",
				Email: "florianmkimmel@gmail.com",
			},
		},
		EnableBashCompletion: true,
		Commands: []*cli.Command{
			{
				Name:    "open",
				Aliases: []string{"o"},
				Usage:   "Open the current episode in the browser",
				Action: func(c *cli.Context) error {
					err := cmd.Open(state.StateFile{}, config.Dir(), config.ConfigurationFile{})

					if err != nil {
						return cli.Exit("", 1)
					}

					return nil
				},
			},
			{
				Name:    "state",
				Aliases: []string{"s"},
				Usage:   "Display current state of the episode",
				Action: func(c *cli.Context) error {
					printLogo()
					err := cmd.State(state.StateFile{}, config.Dir(), config.ConfigurationFile{})

					if err != nil {
						return cli.Exit("", 1)
					}

					return nil
				},
			},
			{
				Name:    "check",
				Aliases: []string{"c"},
				Usage:   "Check if all requirements are met",
				Action: func(c *cli.Context) error {
					printLogo()
					err := cmd.Check(config.ConfigurationFile{}, config.Dir())

					if err != nil {
						return cli.Exit("", 1)
					}

					return nil
				},
			},
			{
				Name:    "publish",
				Aliases: []string{"p"},
				Usage:   "Start automated publishing process",
				Action: func(c *cli.Context) error {
					printLogo()
					err := cmd.Publish(config.ConfigurationFile{}, state.StateFile{}, input.Stdin{}, config.Dir())

					if err != nil {
						return cli.Exit("", 1)
					}

					return nil
				},
			},
			{
				Name:    "chapter",
				Aliases: []string{"se"},
				Usage:   "Managing chapter marks during recording",
				Subcommands: []*cli.Command{
					{
						Name:  "add",
						Usage: "add a new chapter mark",
						Action: func(cCtx *cli.Context) error {
							chapter, err := state.EnterChapterMark(state.StateFile{}, input.Stdin{})

							if chapter.Name != "" && err == nil {
								fmt.Printf("Chapter name: %s, Time: %s", chapter.Name, chapter.Time)
							}

							if err != nil {
								return cli.Exit("", 1)
							}

							return nil
						},
					},
					{
						Name:  "start",
						Usage: "add start of recording",
						Action: func(cCtx *cli.Context) error {
							chapter, err := state.StartEpisode(state.StateFile{})

							if chapter.Name != "" && err == nil {
								fmt.Printf("Chapter name: %s, Time: %s", chapter.Name, chapter.Time)
							}

							if err != nil {
								return cli.Exit("", 1)
							}

							return nil
						},
					},
					{
						Name:  "end",
						Usage: "add end of recording",
						Action: func(cCtx *cli.Context) error {
							chapter, err := state.EndEpisode(state.StateFile{})

							if chapter.Name != "" && err == nil {
								fmt.Printf("Chapter name: %s, Time: %s", chapter.Name, chapter.Time)
							}

							if err != nil {
								return cli.Exit("", 1)
							}

							return nil
						},
					},
					{
						Name:  "toggle-pause",
						Usage: "toggle pause on/off",
						Action: func(cCtx *cli.Context) error {
							chapter, err := state.TogglePauseEpisode(state.StateFile{})

							if chapter.Name != "" && err == nil {
								fmt.Printf("Chapter name: %s, Time: %s", chapter.Name, chapter.Time)
							}

							if err != nil {
								return cli.Exit("", 1)
							}

							return nil
						},
					},
					{
						Name:  "export",
						Usage: "export chapter marks",
						Action: func(cCtx *cli.Context) error {
							err := state.Export(state.StateFile{})
							if err != nil {
								return cli.Exit("", 1)
							}

							return nil
						},
					},
				},
			},
		},
	}

	if err := app.Run(os.Args); err != nil {
		log.Fatal(err)
	}
}

func printLogo() {
	fmt.Println("")
	fmt.Println("██████╗  ██████╗ ██████╗ ███████╗██╗      ██████╗ ██╗    ██╗")
	fmt.Println("██╔══██╗██╔═══██╗██╔══██╗██╔════╝██║     ██╔═══██╗██║    ██║")
	fmt.Println("██████╔╝██║   ██║██║  ██║█████╗  ██║     ██║   ██║██║ █╗ ██║")
	fmt.Println("██╔═══╝ ██║   ██║██║  ██║██╔══╝  ██║     ██║   ██║██║███╗██║")
	fmt.Println("██║     ╚██████╔╝██████╔╝██║     ███████╗╚██████╔╝╚███╔███╔╝")
	fmt.Println("╚═╝      ╚═════╝ ╚═════╝ ╚═╝     ╚══════╝ ╚═════╝  ╚══╝╚══╝ ")
	fmt.Println("")
}
