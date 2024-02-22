package targets

import (
	"bytes"
	"fmt"
	"io"
	"os"
	config "podflow/internal/configuration"

	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/s3"
)

func S3Upload(awsConfig config.S3) error {
	fmt.Println("  Uploading files to S3")
	for _, bucket := range awsConfig.Buckets {
		fmt.Printf("\n  Uploading files to bucket %s \n", bucket.Name)
		sess, err := session.NewSession(&aws.Config{
			Region: aws.String(bucket.Region),
		})
		if err != nil {
			return err
		}
		svc := s3.New(sess)

		for _, s3File := range bucket.Files {
			fmt.Printf("  Uploading file %s to %s \n", s3File.Source, s3File.Target)
			file, err := os.Open(s3File.Source)

			if err != nil {
				return err
			}

			defer file.Close()

			var buf bytes.Buffer
			if _, err := io.Copy(&buf, file); err != nil {
				return err
			}

			_, err = svc.PutObject(&s3.PutObjectInput{
				Bucket: aws.String(bucket.Name),
				Key:    aws.String(s3File.Target),
				Body:   bytes.NewReader(buf.Bytes()),
			})

			if err != nil {
				return err
			}
		}
	}

	return nil
}
