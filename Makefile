ACP_SERVER_URL = $(shell yq eval '.acp.serverURL' ./values/kube-acp-stack.yaml)

ifneq (,$(wildcard ./.env))
    include .env
    export
endif

ifndef ACP_CHARTS_PATH
	KUBE_ACP_STACK_CHART = acp/kube-acp-stack
else
	KUBE_ACP_STACK_CHART = ${ACP_CHARTS_PATH}/kube-acp-stack
endif

### MAIN TARGETS ###
all: prepare deploy verify

prepare: create-cluster prepare-helm prepare-cluster

deploy: install-ingress-controller install-acp-stack

verify: wait-acp check-acp-server-responsivness

### AUXILIARIES ###
create-cluster:
	kind create cluster \
		--name acp \
		--config ./config/kind-cluster-config.yaml

prepare-helm:
	helm repo add acp https://charts.cloudentity.io
	helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
	helm repo add jetstack https://charts.jetstack.io
	helm repo update
ifdef ACP_CHARTS_PATH
	yq eval '(.dependencies[]|select(.name == "acp").repository) |= "file://../acp"' "${KUBE_ACP_STACK_CHART}/Chart.yaml --inplace
	helm dependency update "${KUBE_ACP_STACK_CHART}"
endif

prepare-cluster:
	kubectl create namespace acp-system
	kubectl create namespace nginx
	kubectl create secret docker-registry docker.cloudentity.io \
		--namespace acp-system \
		--docker-server docker.cloudentity.io \
		--docker-username ${DOCKER_USER} \
		--docker-password ${DOCKER_PWD}

install-ingress-controller:
	helm upgrade ingress-nginx ingress-nginx/ingress-nginx \
		--values ./values/ingress-nginx.yaml \
		--namespace nginx \
		--timeout 2m \
		--install \
		--wait

install-acp-stack:
	helm upgrade acp ${KUBE_ACP_STACK_CHART} \
		--values ./values/kube-acp-stack.yaml \
		--namespace acp-system \
		--timeout 5m \
		--install

install-istio-authorizer:
	helm upgrade istio-authorizer acp/istio-authorizer \
		--values ./values/istio-authorizer.yaml \
		--namespace acp-system \
		--timeout 5m \
		--install \
		--wait

install-istio:
	curl --location https://istio.io/downloadIstio | ISTIO_VERSION=1.9.3 TARGET_ARCH=x86_64  sh -
	./istio-1.9.3/bin/istioctl install --filename ./config/ce-istio-profile.yaml --skip-confirmation
	kubectl label namespace default istio-injection=enabled
	rm --recursive --force ./istio-1.9.3

wait-acp:
	kubectl wait deploy/acp \
		--for condition=available \
		--namespace acp-system \
		--timeout 5m

watch:
	watch kubectl get pods --all-namespaces

uninstall-acp:
	helm uninstall acp --namespace acp-system

delete-cluster:
	kind delete cluster --name acp

## helpers
deploy-cmd-pod:
	kubectl apply --filename https://raw.githubusercontent.com/istio/istio/release-1.9/samples/sleep/sleep.yaml

check-istio-ingress:
	curl http://localhost:15021/healthz/ready --verbose

install-example:
	kubectl apply --filename ./examples/httpbin

install-countries:
	docker build examples/countries/ --tag countries:demo
	kind load docker-image countries:demo --name acp
	kubectl apply --filename ./examples/countries

install-example-resort:
	docker build examples/resort/ --tag resort:demo
	kind load docker-image resort:demo --name acp
	kubectl apply --filename ./examples/resort

uninstall-example-resort:
	kubectl delete --filename ./examples/resort

install-cert-manager:
	kubectl create namespace cert-manager
	kubectl apply --filename https://github.com/jetstack/cert-manager/releases/download/v1.3.1/cert-manager.crds.yaml
	helm install \
		cert-manager jetstack/cert-manager \
		--namespace cert-manager \
		--create-namespace \
		--version v1.3.1
	kubectl wait deploy/cert-manager-webhook --for condition=available --namespace cert-manager --timeout 10m
	kubectl apply --filename config/cert-issuer.yaml

install-openbanking:
	kubectl create namespace acp-ob
	helm install acp-ob acp/openbanking --namespace acp-ob

check-acp-server-responsivness:
	curl "${ACP_SERVER_URL}"/alive \
		--resolve "$(shell echo ${ACP_SERVER_URL} | sed 's#https\?://##')":127.0.0.1 \
		--retry 60 \
		--retry-delay 1 \
		--retry-max-time 60 \
		--insecure \
		--fail

debug:
	-kubectl get all --all-namespaces
	-kubectl logs daemonset/kindnet --namespace kube-system
	-kubectl daemonset/kube-proxy --namespace kube-system
	-kubectl deploy/acp --namespace kube-system
	-kubectl deploy/ingress-nginx-controller --namespace kube-system
	-kubectl logs deploy/coredns --namespace kube-system
	-kubectl logs deploy/local-path-provisioner --namespace local-path-storage
	-kubectl describe pod --selector app.kubernetes.io/name=acp --namespace acp-system

## tests

TEST_DOCKER_VERSION=1.17.0

test-prepare-grid:
	docker run --detach --rm \
		--volume /dev/shm:/dev/shm \
		--memory 2048M \
		--name standalone-chrome \
		--network host \
		--add-host acp.acp-system:127.0.0.1 \
		selenium/standalone-chrome:3.141.59

test-prepare-runner:
	docker pull docker.cloudentity.io/acceptance-tests:${TEST_DOCKER_VERSION}
	docker run --tty --detach --rm \
		--name test-runner \
		--network host \
		--add-host acp.acp-system:127.0.0.1 \
		--add-host standalone-chrome:127.0.0.1 \
		--user 1000:1000 \
		docker.cloudentity.io/acceptance-tests:${TEST_DOCKER_VERSION} /bin/sh

test-prepare: test-prepare-grid test-prepare-runner

test-%:
	docker exec --env BASE_URL="https://acp.acp-system:8443" test-runner /qa/test-acceptance.sh $*

test-clean:
	docker stop standalone-chrome test-runner; true

test-copy-results:
	rm --recursive --force temp; \
	mkdir temp &&	\
	docker cp test-runner:/qa/tests/web/target/allure-results temp

graphql-demo:
	make all
	make install-istio
	kubectl get configmaps  istio -n istio-system -o yaml | python examples/graphql-demo/istio-configmap.py | kubectl apply -f -
	kubectl apply -f  examples/graphql-demo/authorization_policy.yaml
	kubectl rollout restart deployment/istiod -n istio-system
	make install-istio-authorizer
	kubectl apply -f  examples/graphql-demo/parse-body.yaml
	make install-countries