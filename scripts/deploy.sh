#!/bin/bash

MODE=$1
REPO=$2
BRANCH=$3
TAG=$4
DOCKER_REGISTRY=docker.cloudentity.io

if [ -z "$DOCKER_USERNAME" ] || [ -z "$DOCKER_PASSWORD" ]; then
    echo "No exported DOCKER_USERNAME or DOCKER_PASSWORD found. Please provide the credentials."
    read -r -p "Enter Docker Username for $DOCKER_REGISTRY: " DOCKER_USERNAME
    read -r -s -p "Enter Docker Password for $DOCKER_REGISTRY: " DOCKER_PASSWORD
    echo
fi

TEMP_DOCKER_CONFIG=$(mktemp -d)
if ! echo "$DOCKER_PASSWORD" | DOCKER_CONFIG="$TEMP_DOCKER_CONFIG" docker login -u "$DOCKER_USERNAME" --password-stdin "$DOCKER_REGISTRY" > /dev/null 2>&1; then
    echo "Invalid Docker credentials for $DOCKER_REGISTRY. Please provide valid credentials and try again."
    rm -rf "$TEMP_DOCKER_CONFIG"
    exit 1
fi
rm -rf "$TEMP_DOCKER_CONFIG"

echo
echo "Installing Flux..."
$RUN flux install

echo
echo "Setting up SOPS secret..."
$RUN bash -c "kubectl --namespace flux-system create secret generic sops-gpg \
    --from-file=sops.asc=./secrets/base/private.key \
    --output=yaml --dry-run=client | kubectl apply --filename -"

echo
echo "Setting up Cloudentity docker registry secret..."
$RUN bash -c "kubectl --namespace flux-system create secret generic docker-cloudentity \
    --from-literal=docker_auth=$(printf '%s:%s' "$DOCKER_USERNAME" "$DOCKER_PASSWORD" | base64 | tr -d '\n') \
    --output=yaml --dry-run=client | kubectl apply --filename -"

echo
echo "Configuring Git source..."
$RUN flux create source git flux-system \
    --url="$REPO" \
    --tag="$TAG" \
    --branch="$BRANCH"

echo
echo "Configuring Git path..."
$RUN flux create kustomization flux-system \
    --source=flux-system \
    --wait=true \
    --path=./clusters/"$MODE"
