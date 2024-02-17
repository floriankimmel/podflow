MODULE_NAME = podflow
BRANCH_NAME = $(shell git rev-parse --abbrev-ref HEAD)
BINARY_NAME = $(if $(filter $(BRANCH_NAME),main),$(MODULE_NAME),$(MODULE_NAME)-$(BRANCH_NAME))

.PHONY: build

build:
	go mod tidy
	go build -o bin/$(BINARY_NAME) ./cmd/podflow/
	cp bin/$(BINARY_NAME) $(HOME)/go/bin/$(BINARY_NAME)

test: build
	go test -v -cover ./...
