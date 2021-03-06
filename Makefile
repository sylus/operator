PWD := $(shell pwd)
ifeq '${CI}' 'true'
VERSION ?= dev
else
VERSION ?= $(shell git describe --tags)
endif
TAG ?= "minio/k8s-operator:$(VERSION)"
LDFLAGS ?= "-s -w -X main.Version=$(VERSION)"

GOPATH := $(shell go env GOPATH)
GOARCH := $(shell go env GOARCH)
GOOS := $(shell go env GOOS)

KUSTOMIZE_HOME=operator-kustomize
KUSTOMIZE_CRDS=$(KUSTOMIZE_HOME)/crds/

PLUGIN_HOME=kubectl-minio

LOGSEARCHAPI=logsearchapi
LOGSEARCHAPI_TAG ?= "minio/logsearchapi:$(VERSION)"

all: build logsearchapi

getdeps:
	@echo "Checking dependencies"
	@mkdir -p ${GOPATH}/bin
	@which golangci-lint 1>/dev/null || (echo "Installing golangci-lint" && curl -sSfL https://raw.githubusercontent.com/golangci/golangci-lint/master/install.sh | sh -s -- -b $(GOPATH)/bin v1.27.0)
	@which controller-gen 1>/dev/null || (echo "Installing controller-gen" && GO111MODULE=on go get sigs.k8s.io/controller-tools/cmd/controller-gen@v0.3.0)
	@which statik 1>/dev/null || (echo "Installing statik" && GO111MODULE=off go get github.com/rakyll/statik)

verify: getdeps govet gotest lint

build: regen-crd verify plugin
	@CGO_ENABLED=0 GOOS=linux go build -trimpath --ldflags $(LDFLAGS) -o minio-operator
	@docker build -t $(TAG) .

install: all
	@docker push $(TAG)

lint:
	@echo "Running $@ check"
	@GO111MODULE=on golangci-lint cache clean
	@GO111MODULE=on golangci-lint run --timeout=5m --config ./.golangci.yml

govet:
	@go vet ./...

gotest:
	@go test -race ./...

clean:
	@echo "Cleaning up all the generated files"
	@find . -name '*.test' | xargs rm -fv
	@find . -name '*~' | xargs rm -fv
	@find . -name '*.zip' | xargs rm -fv

regen-crd:
	@GO111MODULE=on go get sigs.k8s.io/controller-tools/cmd/controller-gen@v0.4.1
	@controller-gen crd:trivialVersions=true paths="./..." output:crd:artifacts:config=$(KUSTOMIZE_CRDS)

statik:
	@echo "Building static assets"
	@statik -src=$(KUSTOMIZE_HOME) -dest $(PLUGIN_HOME) -f

plugin: regen-crd
	@echo "Building 'kubectl-minio' binary"
	@(cd $(PLUGIN_HOME); go build -o kubectl-minio main.go)

.PHONY: logsearchapi
logsearchapi:
	@echo "Building 'logsearchapi' binary"
	@(cd $(LOGSEARCHAPI); \
		go vet ./... && \
		go test -race ./... && \
		GO111MODULE=on ${GOPATH}/bin/golangci-lint cache clean && \
		GO111MODULE=on ${GOPATH}/bin/golangci-lint run --timeout=5m --config ../.golangci.yml && \
		go build && \
		docker build -t $(LOGSEARCHAPI_TAG) . \
   )
