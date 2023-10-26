#!/bin/bash

MODE=$1

declare -a components=(
    "cluster:5m"
    "crds:5m"
)

if [ "$MODE" != "dev" ]; then
    components+=("kyverno:5m")
fi

components+=(
    "cert-manager:5m"
)

if [ "$MODE" != "dev" ] && [ "$MODE" != "base" ]; then
    components+=(
        "keda:5m"
        "reloader:5m"
        "metrics-server:5m"
    )
fi

components+=(
    "nginx:30m"
    "cockroachdb:30m"
    "spicedb:30m"
    "redis:30m"
    "timescaledb:30m"
)

if [ "$MODE" != "dev" ] && [ "$MODE" != "base" ]; then
    components+=("monitoring:15m")
fi

components+=(
    "acp-faas:5m"
    "lightweight-tests:5m"
    "acp:15m"
)

total=${#components[@]}
count=0

echo "Starting deployment... [0%]"

for pair in "${components[@]}"; do
    IFS=":" read -r component timeout <<< "$pair"

    if kubectl wait kustomization/"$component" --for=condition=ready --timeout="$timeout" --namespace flux-system >/dev/null 2>&1; then
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

