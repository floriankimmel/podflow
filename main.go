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
                Flags: []cli.Flag{
                    &cli.BoolFlag{ Name: "skip-youtube" },
                },
                Action: func(c *cli.Context) error {
                    err := cmd.Check(c.Bool("skip-youtube"))

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
                Flags: []cli.Flag{
                    &cli.BoolFlag{ Name: "skip-ftp"},
                    &cli.BoolFlag{ Name: "skip-aws"},
                    &cli.BoolFlag{ Name: "skip-auphonic"},
                    &cli.BoolFlag{ Name: "skip-download"},
                    &cli.BoolFlag{ Name: "skip-blogpost"},
                    &cli.BoolFlag{ Name: "skip-youtube"},
                },
                Action: func(c *cli.Context) error {
                    skipFtp := c.Bool("skip-ftp")
                    skipAws := c.Bool("skip-aws")
                    skipAuphonic := c.Bool("skip-auphonic")
                    skipDownload := c.Bool("skip-download")
                    skipBlogpost := c.Bool("skip-blogpost")
                    skipYoutube := c.Bool("skip-youtube")
                    err := cmd.Publish(skipFtp, skipAws, skipAuphonic, skipDownload, skipBlogpost, skipYoutube)

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

