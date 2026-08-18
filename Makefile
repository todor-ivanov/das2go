VERSION=`git rev-parse --short HEAD`
flags=-ldflags="-s -w -X main.version=${VERSION}"
# flags=-ldflags="-s -w -extldflags -static"

TAG ?= $(shell git describe --tags --exact-match 2>/dev/null || git describe --tags 2>/dev/null)
REGISTRY ?= registry.cern.ch
PROJECT ?= cmsweb
REPOSITORY ?= das-server
IMAGE ?= $(REGISTRY)/$(PROJECT)/$(REPOSITORY)
DOCKER_BUILD_DIR ?= .docker.build
CONFIG_REPO ?= https://github.com/dmwm/CMSKubernetes
CONFIG_BRANCH ?= master

DOCKER_ACTION := $(word 2,$(MAKECMDGOALS))
DOCKER_REF := $(word 3,$(MAKECMDGOALS))

ifeq (docker,$(firstword $(MAKECMDGOALS)))
override TAG := $(DOCKER_REF)
export TAG
endif

.PHONY: all build build_debug build_all build_osx build_linux build_power8 \
	build_arm64 build_windows install clean test test1 upload docker \
	docker-build docker-push

all: build

upload:
	$(MAKE) docker-build
	$(MAKE) docker-push

docker:
	@case "$(DOCKER_ACTION)" in \
		build) \
			[ "$(words $(MAKECMDGOALS))" -eq 3 ] && [ -n "$(DOCKER_REF)" ] || { echo "Usage: make docker build {localtree|dev|<release-tag>}"; exit 1; }; \
			$(MAKE) docker-build ;; \
		push) \
			[ "$(words $(MAKECMDGOALS))" -eq 3 ] && [ -n "$(DOCKER_REF)" ] || { echo "Usage: make docker push {localtree|dev|<release-tag>}"; exit 1; }; \
			$(MAKE) docker-push ;; \
		*) echo "Usage: make docker {build|push} {localtree|dev|<release-tag>}"; exit 1 ;; \
	esac

# The second word in `make docker build` or `make docker push` is also parsed
# by make as a goal. These targets prevent it from running a second action.
ifeq (docker,$(firstword $(MAKECMDGOALS)))
.PHONY: push
push:
	@true
%:
	@true
endif

docker-build:
	@set -e; \
	[ -n "$(TAG)" ] || { echo "TAG is required; use localtree, dev, or a release tag"; exit 1; }; \
	case "$(TAG)" in \
		localtree|dev) build_mode="dev" ;; \
		*) \
			echo "$(TAG)" | grep -Eq '^v?[0-9]+\.[0-9]+\.[0-9]+(rc[0-9]+)?$$' || { \
				echo "TAG=$(TAG) is not localtree, dev, or a release tag"; exit 1; \
			}; \
			build_mode="tag" ;; \
	esac; \
	mkdir -p "$(DOCKER_BUILD_DIR)"; \
	curl -kfsSL $(CONFIG_REPO)/raw/$(CONFIG_BRANCH)/docker/das-server/Dockerfile -o "$(DOCKER_BUILD_DIR)/Dockerfile"; \
	curl -kfsSL $(CONFIG_REPO)/raw/$(CONFIG_BRANCH)/docker/das-server/run.sh -o "$(DOCKER_BUILD_DIR)/run.sh"; \
	chmod +x "$(DOCKER_BUILD_DIR)/run.sh"; \
	if [ "$$build_mode" = "dev" ]; then \
		curl -kfsSL $(CONFIG_REPO)/raw/$(CONFIG_BRANCH)/docker/das-server/Dockerfile.dev -o "$(DOCKER_BUILD_DIR)/Dockerfile.dev"; \
		source_dir="$(DOCKER_BUILD_DIR)/src"; \
		source_tmp="$(DOCKER_BUILD_DIR)/src.tmp"; \
		source_archive="$(DOCKER_BUILD_DIR)/src.tar"; \
		rm -rf "$$source_dir" "$$source_tmp"; \
		rm -f "$$source_archive"; \
		mkdir -p "$$source_tmp"; \
		tar --exclude='./.git' --exclude='./.agents' --exclude='./.codex' --exclude='./.docker.build' \
			--exclude='./tmp' --exclude='./build' \
			--exclude='./das2go' --exclude='./das2go_*' --exclude='./pkg' \
			-cf "$$source_archive" .; \
		tar -xf "$$source_archive" -C "$$source_tmp"; \
		rm -f "$$source_archive"; \
		mv "$$source_tmp" "$$source_dir"; \
		docker build -f "$(DOCKER_BUILD_DIR)/Dockerfile.dev" "$(DOCKER_BUILD_DIR)" --tag "$(IMAGE):$(TAG)"; \
	else \
		sed -i -e "s,ENV TAG=.*,ENV TAG=$(TAG),g" "$(DOCKER_BUILD_DIR)/Dockerfile"; \
		docker build "$(DOCKER_BUILD_DIR)" --tag "$(IMAGE):$(TAG)"; \
	fi; \
	docker image inspect "$(IMAGE):$(TAG)" >/dev/null

docker-push:
	@set -e; \
	[ -n "$(TAG)" ] || { echo "TAG is required; use localtree, dev, or a release tag"; exit 1; }; \
	case "$(TAG)" in \
		localtree|dev) stable="false" ;; \
		*) \
			echo "$(TAG)" | grep -Eq '^v?[0-9]+\.[0-9]+\.[0-9]+(rc[0-9]+)?$$' || { \
				echo "TAG=$(TAG) is not localtree, dev, or a release tag"; exit 1; \
			}; \
			case "$(TAG)" in *rc[0-9]*) stable="false" ;; *) stable="true" ;; esac ;; \
	esac; \
	docker image inspect "$(IMAGE):$(TAG)" >/dev/null || { \
		echo "Docker image $(IMAGE):$(TAG) does not exist locally; run 'make docker build $(TAG)' first"; \
		exit 1; \
	}; \
	docker login "$(REGISTRY)"; \
	docker push "$(IMAGE):$(TAG)"; \
	if [ "$$stable" = "true" ]; then \
		docker tag "$(IMAGE):$(TAG)" "$(IMAGE):$(TAG)-stable"; \
		docker push "$(IMAGE):$(TAG)-stable"; \
	fi

ifeq (docker,$(firstword $(MAKECMDGOALS)))
build:
	@true
else
build:
	GODEBUG=netdns=go CGO_ENABLED=0 go clean; rm -rf pkg; go build ${flags}
endif

build_debug:
	go clean; rm -rf pkg; go build ${flags} -gcflags="-m -m"

build_all: build_osx build_linux build

build_osx:
	go clean; rm -rf pkg das2go_osx; GOOS=darwin go build ${flags}
	mv das2go das2go_osx

build_linux:
	go clean; rm -rf pkg das2go_linux; GOOS=linux go build ${flags}
	mv das2go das2go_linux

build_power8:
	go clean; rm -rf pkg das2go_power8; GOARCH=ppc64le GOOS=linux go build ${flags}
	mv das2go das2go_power8

build_arm64:
	go clean; rm -rf pkg das2go_arm64; GOARCH=arm64 GOOS=linux go build ${flags}
	mv das2go das2go_arm64

build_windows:
	go clean; rm -rf pkg das2go.exe; GOARCH=amd64 GOOS=windows go build ${flags}

install:
	go install

clean:
	go clean; rm -rf pkg

test : test1

test1:
	cd test; go test
