package targets

import (
	"log"
	"time"
    "github.com/jlaffaye/ftp"
)

func FtpUpload() {
    c, err := ftp.Dial("ftp.example.org:21", ftp.DialWithTimeout(5*time.Second))
    if err != nil {
        log.Fatal(err)
    }

    err = c.Login("anonymous", "anonymous")
    if err != nil {
        log.Fatal(err)
    }

    // Do something with the FTP conn

    if err := c.Quit(); err != nil {
        log.Fatal(err)
    }
}

