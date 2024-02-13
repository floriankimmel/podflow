package targets_test

import (
	"net/http"
	"net/http/httptest"
	"podflow/internal/targets"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("Calling an http endpoint", func() {
	It("will lead to a successful response", func() {
		mux := http.NewServeMux()

		mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
			_, err := w.Write([]byte(`{}`))

			if err != nil {
				w.WriteHeader(500)
			}
		})

		testServer := httptest.NewServer(mux)

		defer testServer.Close()

		headers := map[string]string{
			"Content-Type": "application/json",
		}
		response, err := targets.SendHTTPRequest("POST", testServer.URL, headers, nil)

		Expect(err).Should(BeNil())
		Expect(response.Status).Should(Equal(200))

	})

})
