all: create-cluster prepare-helm prepare-cluster install-acp-stack

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
		--docker-username=appd \
		--docker-password=pJbClix17o3n

install-acp-stack:
	helm upgrade --install acp acp/kube-acp-stack --values ./values/kube-acp-stack.yaml -n acp-system
	kubectl -n acp-system wait deploy/acp --for condition=available --timeout=10m
	helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx --values ./values/ingress-nginx.yaml -n nginx
	kubectl -n nginx wait deploy/ingress-nginx-controller --for condition=available --timeout=10m

watch:
	watch kubectl get pods -A

uninstall-acp:
	helm uninstall acp -n acp-system
	helm uninstall ingress-nginx -n nginx

delete-cluster:
	kind delete cluster --name=acp
