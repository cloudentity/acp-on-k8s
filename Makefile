ifneq (,$(wildcard ./.env))
    include .env
    export
endif

all: prepare install-acp-stack

prepare: create-cluster prepare-helm prepare-cluster install-ingress-controller

create-cluster:
	kind create cluster --name acp --config=./config/kind-cluster-config.yaml

prepare-helm:
	helm repo add acp https://charts.cloudentity.io
	helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
	helm repo add jetstack https://charts.jetstack.io
	helm repo update

prepare-cluster:
	kubectl create namespace acp-system
	kubectl create namespace nginx
	kubectl create -n acp-system secret docker-registry docker.cloudentity.io \
		--docker-server=docker.cloudentity.io \
		--docker-username=${DOCKER_USER} \
		--docker-password=${DOCKER_PWD}

install-ingress-controller:
	helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx --values ./values/ingress-nginx.yaml -n nginx
	kubectl -n nginx wait deploy/ingress-nginx-controller --for condition=available --timeout=10m

install-acp-stack:
	helm upgrade --install acp acp/kube-acp-stack --values ./values/kube-acp-stack.yaml -n acp-system
	kubectl -n acp-system wait deploy/acp --for condition=available --timeout=10m

install-istio-authorizer:
	helm upgrade --install istio-authorizer acp/istio-authorizer --values ./values/istio-authorizer.yaml -n acp-system
	kubectl -n acp-system wait deploy/istio-authorizer --for condition=available --timeout=10m

install-istio:
	curl -L https://istio.io/downloadIstio | ISTIO_VERSION=1.9.3 TARGET_ARCH=x86_64  sh -
	./istio-1.9.3/bin/istioctl install -f ./config/ce-istio-profile.yaml -y
	kubectl label namespace default istio-injection=enabled
	rm -rf ./istio-1.9.3

watch:
	watch kubectl get pods -A

uninstall-acp:
	helm uninstall acp -n acp-system

delete-cluster:
	kind delete cluster --name=acp

## helpers
deploy-cmd-pod:
	kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.9/samples/sleep/sleep.yaml

check-istio-ingress:
	curl http://localhost:15021/healthz/ready -v

install-example:
	kubectl apply -f ./examples/httpbin

install-countries:
	docker build examples/countries/ -t countries:demo
	kind load docker-image countries:demo --name acp
	kubectl apply -f ./examples/countries

install-example-resort:
	docker build examples/resort/ -t resort:demo
	kind load docker-image resort:demo --name acp
	kubectl apply -f ./examples/resort

uninstall-example-resort:
	kubectl delete -f ./examples/resort

install-cert-manager:
	kubectl create namespace cert-manager
	kubectl apply -f https://github.com/jetstack/cert-manager/releases/download/v1.3.1/cert-manager.crds.yaml
	helm install \
		cert-manager jetstack/cert-manager \
		--namespace cert-manager \
		--create-namespace \
		--version v1.3.1
	kubectl -n cert-manager wait deploy/cert-manager-webhook --for condition=available --timeout=10m
	kubectl apply -f config/cert-issuer.yaml

install-openbanking:
	kubectl create namespace acp-ob
	helm install acp-ob acp/openbanking	-n acp-ob

debug:
	kubectl get all -A
	kubectl -n kube-system logs daemonset/kindnet
	kubectl -n kube-system logs daemonset/kube-proxy
	kubectl -n acp-system logs deploy/acp
	kubectl -n nginx logs deploy/ingress-nginx-controller
	kubectl -n kube-system logs deploy/coredns
	kubectl -n local-path-storage logs deploy/local-path-provisioner
	kubectl -n acp describe pods acp || true

## tests

TEST_DOCKER_VERSION=1.17.0

test-prepare-grid:
	docker run -d --rm \
		-v /dev/shm:/dev/shm \
		-m 2048M \
		--name standalone-chrome \
		--network=host \
		--add-host=acp.acp-system:127.0.0.1 \
		selenium/standalone-chrome:3.141.59

test-prepare-runner:
	docker pull docker.cloudentity.io/acceptance-tests:${TEST_DOCKER_VERSION}
	docker run -t -d --rm \
		--name test-runner \
		--network=host \
		--add-host=acp.acp-system:127.0.0.1 \
		--add-host=standalone-chrome:127.0.0.1 \
		--user 1000:1000 \
		docker.cloudentity.io/acceptance-tests:${TEST_DOCKER_VERSION} /bin/sh

test-prepare: test-prepare-grid test-prepare-runner

test-%:
	docker exec -e BASE_URL="https://acp.acp-system:8443" test-runner /qa/test-acceptance.sh $*

test-clean:
	docker stop standalone-chrome test-runner; true

test-copy-results:
	rm -rf temp; \
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