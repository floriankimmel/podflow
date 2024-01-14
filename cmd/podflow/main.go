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
    logFile, err := os.OpenFile(filepath.Join(dir, folderName + ".log"), os.O_RDWR | os.O_CREATE | os.O_APPEND, 0666)

    if err != nil {
        log.Fatalf("Error opening file: %v", err)
    }

    defer logFile.Close()

    log.SetFlags(log.LstdFlags | log.Lshortfile)
    log.SetOutput(logFile)

    app := &cli.App{
        Name:  "podflow",
        Usage: " A CLI tool for automating everything related to your podcast",
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
                Name:  "check",
                Aliases: []string{"c"},
                Usage: "Check if all requirements are met",
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
                Name:  "publish",
                Aliases: []string{"p"},
                Usage: "Start automated publishing process",
                Action: func(c *cli.Context) error {
                    printLogo()
                    err := cmd.Publish(config.ConfigurationFile{}, state.StateFile{}, input.Stdin{}, config.Dir())

                    if err != nil {
                        return cli.Exit("", 1)
                    }

                    return nil
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
    fmt.Println("██╗     ███████╗██████╗      ██████╗██╗     ██╗")
    fmt.Println("██║     ██╔════╝██╔══██╗    ██╔════╝██║     ██║")
    fmt.Println("██║     █████╗  ██████╔╝    ██║     ██║     ██║")
    fmt.Println("██║     ██╔══╝  ██╔═══╝     ██║     ██║     ██║")
    fmt.Println("███████╗███████╗██║         ╚██████╗███████╗██║")
    fmt.Println("╚══════╝╚══════╝╚═╝          ╚═════╝╚══════╝╚═╝")
    fmt.Println("")
}
