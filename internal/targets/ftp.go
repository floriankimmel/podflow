package targets

import (
	"fmt"
	"io"
	"log"
	"os"
	config "podflow/internal/configuration"
	"time"

	"github.com/jlaffaye/ftp"
)

func FtpDownload(step config.Step) error {
	ftpConfig := step.Download
	filesToDownload := ftpConfig.Files

	c, err := ftp.Dial(ftpConfig.Host+":"+ftpConfig.Port, ftp.DialWithTimeout(5*time.Second))
	if err != nil {
		log.Fatal(err)
	}

	err = c.Login(ftpConfig.Username, ftpConfig.Password)
	if err != nil {
		return err
	}

	for _, fileToDownload := range filesToDownload {
		fmt.Printf("  Downloading file %s to %s \n", fileToDownload.Source, fileToDownload.Target)
		reader, err := c.Retr(fileToDownload.Source)
		if err != nil {
			return err
		}
		defer reader.Close()
		buf, err := io.ReadAll(reader)

		if err != nil {
			return err
		}

		file, err := os.Create(fileToDownload.Target)

		if err != nil {
			return err
		}

		if _, err := file.WriteString(string(buf)); err != nil {
			return err
		}

	}

	if err := c.Quit(); err != nil {
		return err
	}

	return nil
}

func FtpUpload(step config.Step) error {
	ftpConfig := step.FTP
	filesToUpload := ftpConfig.Files

	c, err := ftp.Dial(ftpConfig.Host+":"+ftpConfig.Port, ftp.DialWithTimeout(5*time.Second))
	if err != nil {
		log.Fatal(err)
	}

	fmt.Printf("  Uploading to %s", ftpConfig.Host)
	err = c.Login(ftpConfig.Username, ftpConfig.Password)
	if err != nil {
		return err
	}

	for _, fileToUpload := range filesToUpload {
		fmt.Printf("\n  Uploading file %s to %s \n", fileToUpload.Source, fileToUpload.Target)
		file, err := os.Open(fileToUpload.Source)
		if err != nil {
			return err
		}
		fi, err := file.Stat()
		if err != nil {
			fmt.Println(err)
			return err
		}
		err = c.Stor(fileToUpload.Target, &ProgressReader{
			reader: file,
			total:  fi.Size(),
		})
		if err != nil {
			return err
		}
		file.Close()
	}
	fmt.Printf("\n")

	if err := c.Quit(); err != nil {
		return err
	}

	return nil
}
