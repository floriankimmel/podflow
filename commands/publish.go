package cmd

import (
	"fmt"
    "podflow/configuration"
)

func Publish() error {
    fmt.Println("")
    fmt.Println("██╗     ███████╗██████╗      ██████╗██╗     ██╗")
    fmt.Println("██║     ██╔════╝██╔══██╗    ██╔════╝██║     ██║")
    fmt.Println("██║     █████╗  ██████╔╝    ██║     ██║     ██║")
    fmt.Println("██║     ██╔══╝  ██╔═══╝     ██║     ██║     ██║")
    fmt.Println("███████╗███████╗██║         ╚██████╗███████╗██║")
    fmt.Println("╚══════╝╚══════╝╚═╝          ╚═════╝╚══════╝╚═╝")
    fmt.Println("")

    err := Check()
    if err != nil {
        return err
    }

    episode := config.Episode()

    fmt.Println("")
    fmt.Printf(" Start automatic workflow for file %s \n", episode)
 
    return nil

}
