package wordpress_test

import (
	"testing"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

func TestWordpress(t *testing.T) {
	RegisterFailHandler(Fail)
	RunSpecs(t, "Wordpress Suite")
}
