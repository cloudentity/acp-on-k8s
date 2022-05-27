# acp-on-k8s

## Overview

This repository's primary purpose is to enable you to rapidly stand up Cloudentity Authorization Control Plane in your local development environment. It takes advantage of a [Kind](https://kind.sigs.k8s.io) a tool for running local Kubernetes clusters using Docker container nodes as well as [ACP helm charts](https://charts.cloudentity.io).

## Prerequisites

* [kind](https://kind.sigs.k8s.io/docs/user/quick-start/#installation) 0.10.x
* [helm](https://helm.sh/docs/intro/install/) 3.x.x
* [kubectl](https://kubernetes.io/docs/tasks/tools/) 1.21.x
* Credentials to access Cloudentity Private Docker Repo - if you are our client, you can find it in your Support Portal; if you are not and you want to check out our product, feel free to request access via our [website](https://cloudentity.com).

## Quickstart
1. For `kind` tool please follow the instructions below to install globally. For the rest tools please follow the official instructions linked above.

On Linux:
```
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.10.0/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/
```
On macOS:
```
brew install kind
```
2. Add environment variables `DOCKER_USER` and `DOCKER_PWD` for Cloudentity Private Docker Repo:
```
export DOCKER_USER=<user>
export DOCKER_PWD=<password>
```
3. Add local domain to `/etc/hosts`:
``` sh
127.0.0.1 acp.acp-system
```

to /etc/hosts and run

`make all`.

Next go to `https://acp.acp-system:8443/` and log in with `admin`:`admin`
=======
4. Run `make all`.
5. Next go to `https://acp.acp-system:8443/` and log in with `admin`:`admin`

## What is next?

* Check out ACP [documentation](http://docs.authorization.cloudentity.com)
* Install Istio `make install-istio` and experiment with the [MicroPerimeter Authorizer for Istio](https://docs.authorization.cloudentity.com/howto/protect/istio/)
* Integrate your SPA app using our [Auth JS Lib](https://github.com/cloudentity/cloudentity-auth-js)
* Explore strong service mTLS based authentication using [Sample Go mTLS OAuth app](https://github.com/cloudentity/sample-go-mtls-oauth-client)

## Makefile reference

* `make all` - Create a new local Kubernetes cluster and install all ACP components. Runs `create-cluster`, `prepare-helm`, `prepare-cluster` and `install-acp-stack`
* `make create-cluster` -  Creates a new local Kubernetes cluster using configuration stored in `./config/kind-cluster-config.yaml`
* `make prepare-helm` -  Adds necessary helm chart repositories
* `make prepare-cluster` - Creates required namespaces and initializes the docker credentials stored in .env file (please make sure you have `DOCKER_USER` and `DOCKER_PWD` correctly configured in the .env file)
* `make install-acp-stack` - Installs the acp stack using the [ACP helm charts](https://charts.cloudentity.io) and the `acp` release name
* `make install-istio` -  Installs Istio 1.9.3 on the Kubernetes cluster
* `make watch` - Checks the status of the deployment
* `make uninstall-acp` - Uninstalls the `acp` release
* `make delete-cluster` - Deletes Kind based Kubernetes cluster
* `make deploy-cmd-pod` - Deploys the CMD pod in the default namespace; this pod is helpful with the Istio authorization testing.
* `make install-countries` - Deploys the countries GraphQL API in the default namespace; this pod is
  helpful for testing GraphQL authorization. The Coutries API is publicly available
  <https://countries.trevorblades.com/>
* `make install-example` - Deploys example services used for testing and PoC purposes.

## Usage of the CMD Pod

1. Run `make deploy-cmd-pod`
2. Export CMD_POD name: `export CMD_POD=$(kubectl get pod -l app=sleep -o jsonpath={.items..metadata.name})`
3. Run the requested operation in te context of a Kubernetes cluster: `kubectl exec -it $CMD_POD -c sleep -- curl https://acp.acp-system:8443/alive --insecure`

## Running OpenBanking quickstart

1. Add to `values/kube-acp-stack.yaml` following feature flags to ACP:

   ```
   integration_endpoints: true
   system_openbanking_consents_management: true
   openbanking_domestic_payment_consents: true
   system_clients_management: true
   ```

2. Run `make install-openbanking`

## Declarative configuration import for Istio gateways, clients, policies, and APIs

The `mp-istio-authorier` folder contains examples on how to declaratively provide your ACP
configuration and import it to any ACP tenant. To learn more about it, visit
[ACP configuration import documentation](https://docs.authorization.cloudentity.com/guides/developer/protect/istio/configuration_import/?q=configuration%20imp)
=======
## GraphQL demo
Instruction ow to run a GraphQL service and be able to play around.

Prerequisites: make sure you use ACP version that supports GraphQL - 2.0.0 or latest.

1. `make graphql-demo` - installs ACP and all components
2. Add local domain to `/etc/hosts`:
```
127.0.0.1 countries.ingress.k8s
```
3. Go to `https://acp.acp-system:8443/system/admin/app`, log in with `admin` and default system password, switch to system workspace. GraphQL service should be discovered.
4. Go to GraphQL UI service `http://countries.ingress.k8s:9080`, change
5. Change API URL to `http://countries.ingress.k8s:9080/gqlapi`
6. Run queries, example:
```
{
  country(code:"PL") {
    name
    code
  }
}
```
