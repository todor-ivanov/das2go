# DAS development operations

This document covers the manual Docker image workflow in the main `Makefile` and
the DAS fast development loop provided by `devops.mk`.

## Manual Docker image workflow

The main `Makefile` builds and publishes DAS images as:

```
registry.cern.ch/cmsweb/das-server:<tag>
```

Docker, `curl`, and `tar` must be available locally. Run the commands from the
`das2go` source tree.

Build an image from the current local source tree:

```
make docker build localtree
make docker build dev
```

Build a release or release-candidate image using the production DAS Dockerfile:

```
make docker build v04.07.42
make docker build v04.07.43rc1
```

The accepted tags are `localtree`, `dev`, and release tags matching
`v<major>.<minor>.<patch>` with an optional `rc<number>` suffix. The leading `v`
is optional.

Push an existing local image to the CERN registry:

```
make docker push dev
make docker push v04.07.42
```

The push target verifies that the image exists locally and runs `docker login`
before publishing it. Stable releases also publish `<release-tag>-stable`.
Release candidates, `dev`, and `localtree` do not receive a stable alias.

Assignment-based targets are also supported:

```
make docker-build TAG=dev
make docker-push TAG=dev
make upload TAG=v04.07.42
```

`upload` builds and then pushes the selected tag.

### CMSKubernetes image source

The Dockerfiles and runtime script are downloaded from the repository and branch
selected by `CONFIG_REPO` and `CONFIG_BRANCH`. The current defaults point to the
feature branch containing the DAS development Dockerfile:

```
CONFIG_REPO=https://github.com/todor-ivanov/CMSKubernetes
CONFIG_BRANCH=feature_AddDasDockerfileDev_fix-89
```

After `docker/das-server/Dockerfile.dev` is merged upstream, use:

```
make docker build dev \
  CONFIG_REPO=https://github.com/dmwm/CMSKubernetes \
  CONFIG_BRANCH=master
```

The isolated build context is stored under `.docker.build/` and is ignored by Git.
For `localtree` and `dev`, the current source tree is staged there without Git,
Codex, temporary, or previously built content.

The `:dev` image is intended to provide the baseline runtime for the Kubernetes
development Deployment. `devpush` remains responsible for building and copying the
current local DAS executable and runtime payload into the development pod; it does
not build or push an image automatically.

## Kubernetes fast development loop

`devops.mk` provides helper targets for the DAS fast development loop in Kubernetes.

It is intended for testing local `das2go` changes against an existing DAS test/dev deployment without rebuilding and publishing a container image for every change.

## Basic usage

Run targets from the `das2go` source tree:

```
make -f devops.mk <target>
```

The active Kubernetes context is taken from `kubectl config`.

Most top-level targets ask for confirmation before changing the target environment.

## Development server workflow

Initialize the development DAS server deployment and redirect the `das-server` service to it:

```
make -f devops.mk devinit
```

Build `das2go` locally and push the runtime payload into the `das-server-dev` pod:

```
make -f devops.mk devpush
```

Revert the `das-server` service selector back to the regular `das-server` deployment:

```
make -f devops.mk devrevert
```

Typical development cycle:

```
make -f devops.mk devinit
make -f devops.mk devpush
```

Repeat `devpush` after local code changes.

When finished:

```
make -f devops.mk devrevert
```

## DASMaps workflow

Back up the current Mongo DASMaps:

```
make -f devops.mk mapsbackup
```

Generate, validate, push, and import DASMaps into the running `das-mongo` pod:

```
make -f devops.mk mapspush
```

Revert DASMaps from the latest local backup:

```
make -f devops.mk mapsrevert
```

Typical maps cycle:

```
make -f devops.mk mapsbackup
make -f devops.mk mapspush
```

Revert if needed:

```
make -f devops.mk mapsrevert
```

## Important paths

Local Docker build context:

```
.docker.build/
```

Local temporary workspace:

```
tmp/
```

Local generated DASMaps directory:

```
tmp/dasmaps-dev.d/js
```

Remote DASMaps directory inside `das-mongo`:

```
/data/dasmaps-dev.d/js
```

Local DASMaps backups:

```
tmp/dasmaps-dev.d/backup
```

Remote DASMaps backups inside `das-mongo`:

```
/data/dasmaps-dev.d/backup
```

## External repositories

The Makefile may clone/update CMSKubernetes configuration into:

```
tmp/CMSKuberenetes
```

It may clone/update DASTools into:

```
tmp/DASTools
```

These directories are local development workspace state and are ignored by Git.

## Target summary

`devinit`

Prepares the development deployment and redirects traffic to `das-server-dev`.

`devpush`

Builds `das2go`, copies the binary and runtime payload into `das-server-dev`, and restarts the process inside the pod.

`devrevert`

Restores the `das-server` service selector back to the normal `das-server` pods.

`mapsbackup`

Exports the current Mongo mapping database and stores a timestamped local backup.

`mapspush`

Prepares DASTools, generates DASMaps, validates them, copies them into `das-mongo`, and imports them.

`mapsrevert`

Copies the latest saved DASMaps backup back into `das-mongo` and imports it.

## Notes

This Makefile is for development and operator testing only.

It does not replace the normal release path based on commits, tags, image builds, registry upload, and deployment.
