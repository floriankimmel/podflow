package main

import (
	"fmt"
	"log"
	"os"
    "time"

	"podflow/commands"
	"github.com/urfave/cli/v2"
)

func init() {
    cli.VersionPrinter = func(cCtx *cli.Context) {
        fmt.Printf("Podflow %s \n", cCtx.App.Version)
    }
}

func main() {
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
                    err := cmd.Check()

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
                    err := cmd.Publish()

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

