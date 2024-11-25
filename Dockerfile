FROM alpine:3.20

# buildx automatic ARG
ARG TARGETARCH

ARG FLUX_VERSION=2.2.2
ARG KUBECONFORM_VERSION=0.6.4
ARG KUBERNETES_VERSION=1.29.1
ARG KUSTOMIZE_VERSION=5.3.0
ARG SOPS_VERSION=3.8.1
ARG FILENAME_FORMAT='{kind}-{group}-{version}'

WORKDIR /tmp

RUN mkdir ~/.gnupg

RUN apk add --no-cache --update \
    curl bash gnupg parallel shellcheck \
    python3 py3-pip py3-yaml npm yq git

COPY secrets/base/private.key private.key

RUN gpg --import private.key

RUN npm install -g prettier

RUN curl -LO https://github.com/yannh/kubeconform/releases/download/v${KUBECONFORM_VERSION}/kubeconform-linux-${TARGETARCH}.tar.gz && \
    tar xf kubeconform-linux-${TARGETARCH}.tar.gz -C /usr/local/bin && \
    rm kubeconform-linux-${TARGETARCH}.tar.gz

RUN curl -L https://dl.k8s.io/release/v${KUBERNETES_VERSION}/bin/linux/${TARGETARCH}/kubectl -o /usr/local/bin/kubectl && \
    chmod +x /usr/local/bin/kubectl

RUN curl -s https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh \
    | bash -s ${KUSTOMIZE_VERSION} && \
    mv kustomize /usr/local/bin

RUN curl -LO https://github.com/fluxcd/flux2/releases/download/v${FLUX_VERSION}/flux_${FLUX_VERSION}_linux_${TARGETARCH}.tar.gz && \
    tar xf flux_${FLUX_VERSION}_linux_${TARGETARCH}.tar.gz -C /usr/local/bin && \
    rm flux_${FLUX_VERSION}_linux_${TARGETARCH}.tar.gz

RUN curl -L https://github.com/getsops/sops/releases/download/v${SOPS_VERSION}/sops-v${SOPS_VERSION}.linux.${TARGETARCH} -o /usr/local/bin/sops && \
    chmod +x /usr/local/bin/sops

RUN git clone -n --depth=1 --filter=tree:0 https://github.com/yannh/kubernetes-json-schema /kubernetes-json-schemas && \
    cd /kubernetes-json-schemas && \
    git sparse-checkout set --no-cone v${KUBERNETES_VERSION}-standalone && \
    git checkout && mv v${KUBERNETES_VERSION}-standalone master-standalone

RUN curl -LO https://github.com/fluxcd/flux2/releases/download/v${FLUX_VERSION}/crd-schemas.tar.gz && \
    tar xf crd-schemas.tar.gz -C /kubernetes-json-schemas/master-standalone && \
    rm crd-schemas.tar.gz

COPY crds crds

RUN curl -LO https://raw.githubusercontent.com/yannh/kubeconform/master/scripts/openapi2jsonschema.py && \
    python3 openapi2jsonschema.py crds/**/*.yaml && \
    mv *.json /kubernetes-json-schemas/master-standalone

WORKDIR /build
