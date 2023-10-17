#!/bin/bash

set -x

kubectl get all --all-namespaces
flux get kustomizations --all-namespaces
flux get helmreleases --all-namespaces
flux get sources all --all-namespaces
kubectl logs deploy/source-controller --namespace flux-system
kubectl logs deploy/kustomize-controller --namespace flux-system
kubectl logs deploy/helm-controller --namespace flux-system
kubectl get pods --all-namespaces --field-selector=status.phase!=Running --no-headers -o custom-columns=':metadata.namespace,:metadata.name' | xargs -n2 kubectl describe pod -n
