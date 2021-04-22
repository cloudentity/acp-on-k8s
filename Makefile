create-cluster:
	kind create cluster --name acp --config=./config/kind-cluster-config.yaml

prepare-helm:
	helm repo add cockroachdb https://charts.cockroachdb.com/
	helm repo add hazelcast https://hazelcast-charts.s3.amazonaws.com/
	helm repo add acp https://charts.cloudentity.io
	helm repo update

prepare-cluster:
	kubectl apply -f ./manifest/acp-namespace.yaml
	kubectl create -n acp-system secret docker-registry artifactory --docker-server=acp.artifactory.cloudentity.com --docker-username=appd --docker-password=pJbClix17o3n

install-acp-stack:
	helm install acp  acp/kube-acp-stack --values ./values/values.yaml -n acp-system 

uninstall-acp:
	helm uninstall acp -n acp-system

delete-cluster:
	kind delete cluster --name=acp

