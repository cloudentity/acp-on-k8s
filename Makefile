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
	helm repo update

prepare-cluster:
	kubectl create namespace acp-system
	kubectl create namespace nginx
	kubectl create -n acp-system secret docker-registry artifactory \
		--docker-server=acp.artifactory.cloudentity.com \
		--docker-username=${DOCKER_USER} \
		--docker-password=${DOCKER_PWD}

install-ingress-controller:
	helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx --values ./values/ingress-nginx.yaml -n nginx
	kubectl -n nginx wait deploy/ingress-nginx-controller --for condition=available --timeout=10m

install-acp-stack:
	helm upgrade --install acp acp/kube-acp-stack --values ./values/kube-acp-stack.yaml -n acp-system
	kubectl -n acp-system wait deploy/acp --for condition=available --timeout=10m

install-istio:
	curl -L https://istio.io/downloadIstio | ISTIO_VERSION=1.9.3 TARGET_ARCH=x86_64  sh -
	./istio-1.9.3/bin/istioctl install -f ./config/ce-istio-profile.yaml -y
	kubectl label namespace default istio-injection=enabled
	rm -rf ./istio-1.9.3

watch:
	watch kubectl get pods -A

uninstall-acp:
	helm uninstall acp -n acp-system
	helm uninstall ingress-nginx -n nginx

delete-cluster:
	kind delete cluster --name=acp

## helpers
deploy-cmd-pod:
	kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.9/samples/sleep/sleep.yaml

check-istio-ingress:
	curl http://localhost:15021/healthz/ready -v

install-example:
	kubectl apply -f ./examples/httpbin
