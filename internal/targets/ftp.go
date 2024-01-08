package targets

import (
	"fmt"
	"log"
	"os"
	config "podflow/internal/configuration"
	"time"

	"github.com/jlaffaye/ftp"
)

func FtpUpload(ftpConfig config.FTP, filesToUpload []config.FileUpload) error {
    c, err := ftp.Dial(ftpConfig.Host + ":" + ftpConfig.Port, ftp.DialWithTimeout(5*time.Second))
    if err != nil {
        log.Fatal(err)
    }

    err = c.Login(ftpConfig.Username, ftpConfig.Password)
    if err != nil {
        return err
    }

    for _, fileToUpload := range filesToUpload {
        fmt.Printf("  Uploading file %s to %s \n", fileToUpload.Source, fileToUpload.Target)
        file, err := os.Open(fileToUpload.Source)
        if err != nil {
            return err
        }
        err = c.Stor(fileToUpload.Target, file)
        if err != nil {
            return err
        }
        file.Close()
    }
    if err != nil {
       return err
    }
    if err := c.Quit(); err != nil {
        return err
    }

    return nil
}

