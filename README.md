# acp-on-k8s

> [!IMPORTANT]  
> We've transitioned to a GitOps-based approach, bringing a more modern and efficient solution to this repository.
>
> For those who would like to access the previous version of the stack, please switch to the `legacy` branch.

## Overview

This repository is designed to facilitate a swift setup of Secureauth's CIAM in both local development environments and production settings. By leveraging tools like Kind - which enables running local Kubernetes clusters using Docker container nodes - and fluxcd for provisioning resources, it offers a streamlined deployment process. Among the resources provisioned is the ACP helm chart. Additionally, the repository provides guidelines and best practices for production deployment.

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/)
- [Kind](https://kind.sigs.k8s.io/docs/user/quick-start/#installation)
- Credentials to access the SecureAuth Private Docker Repository - if you are our client, you can find those in your Support Portal; if you are not and you want to check out our product, feel free to request access via our [website](https://secureauth.com).

## Quickstart

1. Add environment variables `DOCKER_USERNAME` and `DOCKER_PASSWORD` for SecureAuth Private Docker Repository:

```sh
export DOCKER_USERNAME=<user>
export DOCKER_PASSWORD=<password>
```

2. Add local domain to `/etc/hosts`:

```sh
127.0.0.1 default.acp.local
127.0.0.1 system.acp.local
```

3. Run `make all`.
4. Next, go to `https://default.acp.local:8443` and log in with `admin`:`admin`.
5. To log in as a system administrator, go to `https://system.acp.local:8443` and use the credentials `admin`:`peyYXiGEd3RMjCJyKzn6JmUpoey7ti5m`.

## What is next?

- Check out SecureAuth deployment [documentation](https://cloudentity.com/developers/deployment-and-operations/deployment/deployment-overview/)

## Makefile reference

- `make all` - Creates a Kubernetes cluster with all ACP components and runs simple tests: `setup`, `deploy`, `wait`, and `run-lightweight-tests`.
- `make prepare` - Builds a Docker image with the tools used in this repository.
- `make setup` - Creates a Kubernetes cluster using Kind.
- `make deploy` - Deploys the stack using flux to the Kubernetes cluster.
- `make deploy-check` - Lists components that are not ready yet.
- `make wait` - Waits until all the Kubernetes resources are ready.
- `make run-lightweight-tests` - Runs lightweight tests on the deployed resources.
- `make destroy` - Deletes the Kubernetes cluster.
- `make kustomization-build` - Generates raw kustomization files.
- `make kustomization-check-failing` - Checks for failing kustomizations.
- `make kustomization-status` - Watches kustomization status in real time.
- `make helm-check-failing` - Checks for failing helm releases.
- `make helm-status` - Watches helm release status in real time.
- `make sources-check-failing` - Checks for failing sources.
- `make sources-status` - Watches source status in real time.
- `make lint` - Executes various linting checks: `lint-prettier`, `lint-shellcheck`, `lint-kustomization`.
- `make shellcheck-lint` - Shellcheck validation on shell scripts.
- `make kustomization-lint` - Kustomization validation.
- `make prettier-lint` - Prettier style checks.
- `make prettier-format` - Formats code style with Prettier.
- `make decrypt` - Decrypts a SOPS encoded file.
- `make encrypt` - Encrypts a file using SOPS.
- `make debug` - Retrieves resource statuses and fluxCD logs.
