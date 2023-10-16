MODE   ?= base
# dev (dev deployment)
# base (base HA deployment)
# full (base mode with observability enabled [resources heavy])
REPO   ?= https://github.com/cloudentity/acp-on-k8s
BRANCH ?= main
TAG ?= 2.17.0
TOOLBOX_DOCKER_IMAGE ?= cloudentity/toolbox
TOOLBOX_TAG ?= 2.17.0
STEP_CI_TEST_SUITE_PATH ?= scenarios/suite.yml

RUN = docker run --init --rm \
		--network host \
		-v $(shell pwd):/build \
		-v $$HOME/.kube/config:/root/.kube/config ${TOOLBOX_DOCKER_IMAGE}:${TOOLBOX_TAG}

all: setup deploy wait run-lightweight-tests

prepare:
	docker build --platform linux/amd64 --tag ${TOOLBOX_DOCKER_IMAGE}:${TOOLBOX_TAG} .

setup:
	kind create cluster --name=cloudentity --config=scripts/kind-config.yaml

deploy:
	$(RUN) flux install \
	       --components-extra=image-reflector-controller,image-automation-controller
	$(RUN) bash -c "kubectl --namespace flux-system create secret generic sops-gpg \
		--from-file=sops.asc=./secrets/base/private.key \
		--output=yaml --dry-run=client | kubectl apply --filename -"
	$(RUN) bash -c "kubectl --namespace flux-system create secret generic docker-cloudentity \
		--from-literal=docker_auth=$$(echo -n "${DOCKER_USERNAME}:${DOCKER_PASSWORD}" | base64 -w0) \
		--output=yaml --dry-run=client | kubectl apply --filename -"
	$(RUN) flux create source git flux-system \
		--url=$(REPO) \
		--tag=${TAG} \
		--branch=$(BRANCH)
	$(RUN) flux create kustomization flux-system \
		--source=flux-system \
		--wait=true \
		--path=./clusters/${MODE}

wait:
	$(RUN) kubectl wait kustomization/cluster           --for=condition=ready --timeout=5m  --namespace flux-system
	$(RUN) kubectl wait kustomization/crds              --for=condition=ready --timeout=5m  --namespace flux-system
ifeq ($(filter $(MODE),dev),)
	$(RUN) kubectl wait kustomization/kyverno           --for=condition=ready --timeout=5m  --namespace flux-system
endif
	$(RUN) kubectl wait kustomization/cert-manager      --for=condition=ready --timeout=5m  --namespace flux-system
ifeq ($(filter $(MODE),dev base),)
	$(RUN) kubectl wait kustomization/keda              --for=condition=ready --timeout=5m  --namespace flux-system
	$(RUN) kubectl wait kustomization/reloader          --for=condition=ready --timeout=5m  --namespace flux-system
	$(RUN) kubectl wait kustomization/metrics-server    --for=condition=ready --timeout=5m  --namespace flux-system
endif
	$(RUN) kubectl wait kustomization/nginx             --for=condition=ready --timeout=30m --namespace flux-system
	$(RUN) kubectl wait kustomization/cockroachdb       --for=condition=ready --timeout=30m --namespace flux-system
	$(RUN) kubectl wait kustomization/spicedb           --for=condition=ready --timeout=30m --namespace flux-system
	$(RUN) kubectl wait kustomization/redis             --for=condition=ready --timeout=30m --namespace flux-system
	$(RUN) kubectl wait kustomization/timescaledb       --for=condition=ready --timeout=30m --namespace flux-system
ifeq ($(filter $(MODE),dev base),)
	$(RUN) kubectl wait kustomization/monitoring        --for=condition=ready --timeout=15m --namespace flux-system
endif
	$(RUN) kubectl wait kustomization/acp-faas          --for=condition=ready --timeout=5m  --namespace flux-system
	$(RUN) kubectl wait kustomization/lightweight-tests --for=condition=ready --timeout=5m  --namespace flux-system
	$(RUN) kubectl wait kustomization/acp               --for=condition=ready --timeout=15m --namespace flux-system

check-kustomization:
	$(RUN) flux get kustomizations --no-header --status-selector ready=false

watch-kustomization:
	$(RUN) watch flux get kustomizations --all-namespaces

watch-helm:
	$(RUN) watch flux get helmreleases --all-namespaces

run-lightweight-tests:
	@$(RUN) kubectl exec deploy/private-ingress-nginx-controller -n nginx -- sh -c 'curl -k -I https://acp.acp:8443/alive' | grep -q "HTTP/1.1 200 OK" || { \
		echo "Tests have not been executed. Simple http request check on /alive endpoint of acp service ends with failure. Check status of acp pods before the test run." && exit 1; \
	}
	$(RUN) kubectl exec deploy/lightweight-tests -n lightweight-tests -- sh -c 'stepci run $(STEP_CI_TEST_SUITE_PATH) -s client_secret=$${LIGHTWEIGHT_IDP_CLIENT_SECRET}'

destroy:
	kind delete cluster --name=cloudentity

lint: lint-prettier lint-shellcheck lint-kustomization

lint-prettier:
	$(RUN) prettier --check .

lint-shellcheck:
	$(RUN) shellcheck ./scripts/*.sh

lint-kustomization:
	$(RUN) ./scripts/validate.sh

format:
	$(RUN) prettier --write .

decrypt:
	$(RUN) sops -decrypt --in-place ${FILE}

encrypt:
	${RUN} sops --encrypt --in-place --pgp="379B2FD0571BABB20DDF66F7C88D9F4D45AC1770" --encrypted-regex '^(data|stringData)$$' ${FILE}
