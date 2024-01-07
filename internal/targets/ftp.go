package targets

import (
	"io"
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

    for _, fileToUplaod := range filesToUpload {
        file, err := os.Open(fileToUplaod.Source)
        if err != nil {
            return err
        }
        err = c.Stor(fileToUplaod.Target, file)
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

