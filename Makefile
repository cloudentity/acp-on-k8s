MODE   ?= base
# dev (dev deployment)
# base (base HA deployment)
# full (base mode with observability enabled [resources heavy])
REPO   ?= https://github.com/cloudentity/acp-on-k8s
BRANCH ?= main
TAG ?= 
TOOLBOX_DOCKER_IMAGE ?= cloudentity/toolbox
TOOLBOX_TAG ?= latest
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
	@echo -e "\nInstalling Flux..."
	@$(RUN) flux install
	@echo -e "\nSetting up SOPS secret..."
	@$(RUN) bash -c "kubectl --namespace flux-system create secret generic sops-gpg \
		--from-file=sops.asc=./secrets/base/private.key \
		--output=yaml --dry-run=client | kubectl apply --filename -"
	@echo -e "\nSetting up Cloudentity docker registry secret..."
	@$(RUN) bash -c "kubectl --namespace flux-system create secret generic docker-cloudentity \
		--from-literal=docker_auth=$$(printf "${DOCKER_USERNAME}:${DOCKER_PASSWORD}" | base64 | tr -d '\n') \
		--output=yaml --dry-run=client | kubectl apply --filename -"
	@echo -e "\nConfiguring Git source..."
	@$(RUN) flux create source git flux-system \
		--url=$(REPO) \
		--tag=${TAG} \
		--branch=$(BRANCH)
	@echo -e "\nConfiguring Git path..."
	@$(RUN) flux create kustomization flux-system \
		--source=flux-system \
		--wait=true \
		--path=./clusters/${MODE}

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
	@$(RUN) kubectl exec deploy/lightweight-tests -n lightweight-tests -- sh -c 'stepci run $(STEP_CI_TEST_SUITE_PATH) -s client_secret=$${LIGHTWEIGHT_IDP_CLIENT_SECRET}'

destroy:
	kind delete cluster --name=cloudentity

lint: shellcheck-lint kustomization-lint prettier-lint 

shellcheck-lint:
	@$(RUN) shellcheck ./scripts/*.sh

kustomization-lint:
	@$(RUN) ./scripts/validate.sh

prettier-lint:
	@$(RUN) prettier --check .

prettier-format:
	@$(RUN) prettier --write .

decrypt:
	@$(RUN) sops -decrypt --in-place ${FILE}

encrypt:
	@${RUN} sops --encrypt --in-place --pgp="379B2FD0571BABB20DDF66F7C88D9F4D45AC1770" --encrypted-regex '^(data|stringData)$$' ${FILE}

debug:
	@$(RUN) ./scripts/debug.sh
