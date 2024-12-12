MODE   ?= base
# dev (dev deployment)
# base (base HA deployment)
# full (base mode with observability enabled [resources heavy])

# Production Readiness - Use Your Own Source
REPO   ?= https://github.com/cloudentity/acp-on-k8s
BRANCH ?= main
TAG ?= 2.23.0
TOOLBOX_DOCKER_IMAGE ?= cloudentity/toolbox
TOOLBOX_TAG ?= 2.23.0
STEP_CI_TEST_SUITE_PATH ?= scenarios/suite.yml
PRETTIER_PATH ?= .

ifeq ($(CI),true)
    DOCKER_FLAGS = --init
else
    DOCKER_FLAGS = --init --interactive --tty
endif

RUN = docker run $(DOCKER_FLAGS) --rm \
		--network host \
		-v $(shell pwd):/build \
		-v $$HOME/.kube/config:/root/.kube/config ${TOOLBOX_DOCKER_IMAGE}:${TOOLBOX_TAG}

all: setup deploy wait run-lightweight-tests

prepare:
	docker buildx build --tag ${TOOLBOX_DOCKER_IMAGE}:${TOOLBOX_TAG} . --load

setup:
	kind create cluster --name=cloudentity --config=scripts/kind-config.yaml

deploy:
	@RUN="$(RUN)" ./scripts/deploy.sh --mode "$(MODE)" --repo "$(REPO)" --branch "$(BRANCH)" --tag "$(TAG)" --git-username "$(GIT_USERNAME)" --git-password "$(GIT_PASSWORD)"

wait:
	@$(RUN) ./scripts/wait.sh ${MODE}

deploy-check: sources-check-failing kustomization-check-failing helm-check-failing

kustomization-build:
	@$(RUN) kustomize build --load-restrictor=LoadRestrictionsNone ${DIR}

kustomization-check-failing:
	@echo "Checking for not ready Kustomizations:"
	@$(RUN) flux get kustomizations --no-header --status-selector ready=false

kustomization-status:
	@$(RUN) watch flux get kustomizations

helm-check-failing:
	@echo "Checking for not ready HelmReleases"
	@$(RUN) flux get helmreleases --all-namespaces --no-header --status-selector ready=false

helm-status:
	@$(RUN) watch flux get helmreleases --all-namespaces

sources-check-failing:
	@echo "Checking for not ready Sources:"
	@$(RUN) flux get sources all --all-namespaces --no-header --status-selector ready=false

sources-status:
	@$(RUN) watch flux get sources all --all-namespaces

run-lightweight-tests:
	@$(RUN) kubectl exec deploy/private-ingress-nginx-controller -n nginx -- sh -c 'curl -k -I -s https://acp.acp:8443/alive' | grep -q "HTTP/1.1 200 OK" || { \
		echo "Tests have not been executed. Simple http request check on /alive endpoint of acp service ends with failure. Check status of acp pods before the test run." && exit 1; \
	}
	@$(RUN) kubectl exec deploy/lightweight-tests -n lightweight-tests -- sh -c 'node dist/index.js run $(STEP_CI_TEST_SUITE_PATH) -s client_secret=$${LIGHTWEIGHT_IDP_CLIENT_SECRET}'

destroy:
	kind delete cluster --name=cloudentity

lint: shellcheck-lint kustomization-lint prettier-lint

shellcheck-lint:
	@$(RUN) shellcheck ./scripts/*.sh

kustomization-lint:
	@$(RUN) ./scripts/validate.sh

prettier-lint:
	@$(RUN) prettier --check $(PRETTIER_PATH)

prettier-format:
	@$(RUN) prettier --write $(PRETTIER_PATH)

decrypt:
	@$(RUN) sops -decrypt --in-place ${FILE}

encrypt:
	@${RUN} sops --encrypt --in-place --pgp="379B2FD0571BABB20DDF66F7C88D9F4D45AC1770" --encrypted-regex '^(data|stringData)$$' ${FILE}

debug:
	@$(RUN) ./scripts/debug.sh
