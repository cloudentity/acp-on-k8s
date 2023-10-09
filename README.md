# acp-on-k8s

## Overview

This repository is designed to facilitate a swift setup of Cloudentity's Authorization Control Plane in both local development environments and production settings. By leveraging tools like Kind - which enables running local Kubernetes clusters using Docker container nodes - and fluxcd for provisioning resources, it offers a streamlined deployment process. Among the resources provisioned is the ACP helm charts. Additionally, the repository provides guidelines and best practices for production deployment.

## Prerequisites

- [docker](https://docs.docker.com/get-docker/)
- [kind](https://kind.sigs.k8s.io/docs/user/quick-start/#installation)
- Credentials to access Cloudentity Private Docker Repo - if you are our client, you can find it in your Support Portal; if you are not and you want to check out our product, feel free to request access via our [website](https://cloudentity.com).

## Quickstart

1. Add environment variables `DOCKER_USERNAME` and `DOCKER_PASSWORD` for Cloudentity Private Docker Repo:

```sh
export DOCKER_USERNAME=<user>
export DOCKER_PASSWORD=<password>
```

2. Add local domain to `/etc/hosts`:

```sh
127.0.0.1 system.acp.local
```

3. Run `make all`.
4. Next go to `https://system.acp.local:8443` and log in with `admin`:`peyYXiGEd3RMjCJyKzn6JmUpoey7ti5m`

## What is next?

- Check out ACP [documentation](http://docs.authorization.cloudentity.com)

## Makefile reference

- `make all` - Create Kubernetes cluster with all ACP components and runs simple tests: `setup`, `deploy`, `wait` and `run-lightweight-tests`
- `make prepare` - Builds a docker image with tools used in this repository.
- `make setup` - Creates a Kubernetes cluster using kind.
- `make deploy` - Deploys the stack using flux to the Kubernetes cluster.
- `make wait` - Waits until all the Kubernetes resources are ready.
- `make check-kustomization` - Checks if the deployment was successful.
- `make run-lightweight-tests` - Runs lightweight tests on the deployed resources.
- `make destroy` - Deletes the Kubernetes cluster.
- `make watch-kustomization` - Monitors the flux kustomizations in real-time.
- `make watch-helm` - Monitors the flux helmreleases in real-time.
- `make lint` - Executes various linting checks: `lint-prettier`, `lint-shellcheck`, `lint-kustomization`
- `make lint-prettier` - Prettier style checks
- `make lint-shellcheck` - Shellcheck validation on shell scripts
- `make lint-kustomization` - Kustomization validation
- `make format` - Formats code style with Prettier.
- `make decrypt` - Decrypt SOPS encoded file.
- `make encrypt` - Encrypt file using SOPS.
