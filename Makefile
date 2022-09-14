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

prepare: create-cluster prepare-helm prepare-cluster install-ingress-controller prepare-cert

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
	yq eval '(.dependencies[]|select(.name == "acp").repository) |= "file://../acp"' "${KUBE_ACP_STACK_CHART}/Chart.yaml" --inplace
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


prepare-cert:
	#openssl genrsa -out ./cert/rootCA.key 2048
	#openssl req -x509 -new -nodes -key ./cert/rootCA.key -sha256 -days 365  -out ./cert/rootCA.pem -subj "/C=US/ST=WA/L=Seattle/O=Cloudentity/OU=SE/CN=acp-system/emailAddress=info@acp.acp-system"
	openssl req -new -nodes -out ./cert/server.csr -newkey rsa:2048 -keyout ./cert/server.key -subj "/C=US/ST=WA/L=Seattle/O=Cloudentity/OU=SE/CN=acp.acp-system/emailAddress=info@acp.acp-system"
	openssl x509 -req -in ./cert/server.csr -CA ./cert/rootCA.pem -CAkey ./cert/rootCA.key -CAcreateserial -out ./cert/server.crt -days 356 -sha256 -extfile ./cert/certv3.ext
	kubectl delete secret -n acp-system acp-server-tls --ignore-not-found=true
	kubectl create secret tls acp-server-tls --cert=./cert/server.crt --key=./cert/server.key -n acp-system
	kubectl delete secret -n acp-system acp-tls --ignore-not-found=true
	kubectl create secret tls acp-tls --cert=./cert/server.crt --key=./cert/server.key -n acp-system


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
		--timeout 10m \
		--install \
		--version 2.4.1

register-istio-authorizer-local:
	kubectl create secret docker-registry docker.cloudentity.io \
		--namespace acp-istio-authorizer \
		--docker-server docker.cloudentity.io \
		--docker-username ${DOCKER_USER} \
		--docker-password ${DOCKER_PWD}
	helm upgrade register-istio-authorizer-job ../acp-helm-charts/charts/acp-cd/ \
		--values ./values/istio-authorizer/register-istio-authorizer-local.yaml \
		--set clientCredentials.clientID=${IMPORT_JOB_CLIENT_ID} \
		--set clientCredentials.clientSecret=${IMPORT_JOB_SECRET} \
		--set clientCredentials.issuerURL=${ACP_SERVER_URL}/default/system/ \
		--namespace acp-istio-authorizer \
		--create-namespace \
		--timeout 5m \
		--install \
		--wait

register-istio-authorizer-multitenant:
	helm upgrade register-istio-authorizer-job ../acp-helm-charts/charts/acp-cd/ \
		--values ./values/istio-authorizer/register-istio-authorizer-multitenant.yaml \
		--set clientCredentials.clientID=${SYS_IMPORT_JOB_CLIENT_ID} \
		--set clientCredentials.clientSecret=${SYS_IMPORT_JOB_SECRET} \
		--set clientCredentials.issuerURL=${ACP_SERVER_URL}/system/system/ \
		--namespace acp-istio-authorizer \
		--create-namespace \
		--timeout 5m \
		--install \
		--wait


install-istio-authorizer-local:
	helm upgrade istio-authorizer acp/istio-authorizer \
		--values ./values/istio-authorizer/install-istio-authorizer-local.yaml \
		--namespace acp-istio-authorizer \
		--create-namespace \
		--timeout 5m \
		--install \
		--wait

install-istio-authorizer-multitenant:
	helm upgrade istio-authorizer acp/istio-authorizer \
		--values ./values/istio-authorizer/install-istio-authorizer-multitenant.yaml \
		--namespace acp-istio-authorizer \
		--create-namespace \
		--timeout 5m \
		--install \
		--wait

install-istio:
	curl -L https://istio.io/downloadIstio | ISTIO_VERSION=1.13.4 TARGET_ARCH=x86_64  sh -
	./istio-1.13.4/bin/istioctl install -f ./config/ce-istio-profile.yaml -y
	kubectl label namespace default istio-injection=enabled
	rm -rf ./istio-1.13.4

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
	kubectl apply -f ./examples/httpbin
	kubectl apply -f ./examples/echo
	kubectl apply -f ./examples/fortune-teller


uninstall-example:
	kubectl delete -f ./examples/httpbin
	kubectl delete -f ./examples/echo
	kubectl delete -f ./examples/fortune-teller
	
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

protect-httpbin-multitenant:
	helm upgrade protect-httpbin ../acp-helm-charts/charts/acp-cd/ \
		--values ./values/protected-services/define-and-protect-httpbin-multitenant-v1.yaml \
		--set clientCredentials.clientID=${SYS_IMPORT_JOB_CLIENT_ID} \
		--set clientCredentials.clientSecret=${SYS_IMPORT_JOB_SECRET} \
		--set clientCredentials.issuerURL=${ACP_SERVER_URL}/system/system/ \
		--namespace acp-istio-authorizer \
		--create-namespace \
		--timeout 5m \
		--install \
		--wait

protect-httpbin-local:
	helm upgrade protect-httpbin ../acp-helm-charts/charts/acp-cd/ \
		--values ./values/protected-services/assign-local-policy-httpbin.yaml \
		--set clientCredentials.clientID=${IMPORT_JOB_CLIENT_ID} \
		--set clientCredentials.clientSecret=${IMPORT_JOB_SECRET} \
		--set clientCredentials.issuerURL=${ACP_SERVER_URL}/default/system/ \
		--namespace acp-istio-authorizer \
		--create-namespace \
		--timeout 5m \
		--install \
		--wait



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

TEST_DOCKER_VERSION=bbfd227

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

	helm upgrade istio-authorizer acp/istio-authorizer \
	--values ./values/istio-authorizer-graphql.yaml \
	--namespace acp-istio-authorizer \
	--create-namespace \
	--timeout 5m \
	--install \
	--wait
 
	make install-countries
