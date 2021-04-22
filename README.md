# acp-on-k8s

## Prerequisites

* [kind](https://kind.sigs.k8s.io/) 0.10.x
* [helm](https://helm.sh/docs/intro/install/) 3.x.x
* [kubectl](https://kubernetes.io/docs/tasks/tools/) 1.21.x

## Quickstart

Add

``` sh
127.0.0.1 acp.acp-system
```

to /etc/hosts and run `make all`.

Next go to `https://acp.acp-system:8443/`
