#!/bin/bash

MODE=$1

declare -a components=(
    "cluster:kustomization:flux-system:5m"
    "crds:kustomization:flux-system:5m"
)

if [ "$MODE" != "dev" ]; then
    components+=("kyverno:kustomization:flux-system:5m")
fi

components+=("cert-manager:kustomization:flux-system:5m")

if [ "$MODE" != "dev" ] && [ "$MODE" != "base" ]; then
    components+=(
        "keda:kustomization:flux-system:5m"
        "reloader:kustomization:flux-system:5m"
        "metrics-server:kustomization:flux-system:5m"
    )
fi

components+=(
    "nginx:kustomization:flux-system:30m"
    "cockroachdb:kustomization:flux-system:30m"
    "spicedb:kustomization:flux-system:30m"
    "redis:kustomization:flux-system:30m"
    "timescaledb:kustomization:flux-system:30m"
)

if [ "$MODE" != "dev" ] && [ "$MODE" != "base" ]; then
    components+=("monitoring:kustomization:flux-system:15m")
fi

components+=(
    "acp-faas:kustomization:flux-system:5m"
    "lightweight-tests:kustomization:flux-system:5m"
    "acp:kustomization:flux-system:15m"
    "acp-cd:helmrelease:lightweight-tests:10m"
)

total=${#components[@]}
count=0

echo "Starting deployment... [0%]"

for entry in "${components[@]}"; do
    IFS=":" read -r component type namespace timeout <<< "$entry"

    if kubectl wait "$type/$component" --for=condition=ready --timeout="$timeout" --namespace "$namespace" >/dev/null 2>&1; then
        count=$((count + 1))
        percentage=$(echo "scale=2; ($count/$total)*100" | bc)
        echo "Deployed component: $component ($count/$total) [$percentage%] successfully!"
    else
        echo "Failed to deploy component $component!"
        echo "Check if proper mode was set for wait: make wait MODE=base"
        exit 1
    fi
done

echo "All components deployed successfully!"

