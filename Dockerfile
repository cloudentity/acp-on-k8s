FROM alpine:3.18

ARG FLUX_VERSION=2.0.1
ARG KUBECONFORM_VERSION=0.6.1
ARG KUBERNETES_VERSION=1.27.2
ARG KUSTOMIZE_VERSION=5.0.1
ARG SOPS_VERSION=3.8.0
ARG FILENAME_FORMAT='{kind}-{group}-{version}'

WORKDIR /tmp

RUN mkdir ~/.gnupg

RUN apk add --no-cache --update \
    curl bash gnupg parallel shellcheck \
    python3 py3-pip subversion npm yq

COPY secrets/base/private.key private.key

RUN gpg --import private.key

RUN pip3 install --upgrade \
    pip pyaml

RUN npm install -g prettier

RUN curl -LO https://github.com/yannh/kubeconform/releases/download/v${KUBECONFORM_VERSION}/kubeconform-linux-amd64.tar.gz && \
    tar xf kubeconform-linux-amd64.tar.gz -C /usr/local/bin && \
    rm kubeconform-linux-amd64.tar.gz

RUN curl -L https://dl.k8s.io/release/v${KUBERNETES_VERSION}/bin/linux/amd64/kubectl -o /usr/local/bin/kubectl && \
    chmod +x /usr/local/bin/kubectl

RUN curl -s https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh \
    | bash -s ${KUSTOMIZE_VERSION} && \
    mv kustomize /usr/local/bin

RUN curl -LO https://github.com/fluxcd/flux2/releases/download/v${FLUX_VERSION}/flux_${FLUX_VERSION}_linux_amd64.tar.gz && \
    tar xf flux_${FLUX_VERSION}_linux_amd64.tar.gz -C /usr/local/bin

RUN curl -L https://github.com/getsops/sops/releases/download/v${SOPS_VERSION}/sops-v${SOPS_VERSION}.linux.amd64 -o /usr/local/bin/sops && \
    chmod +x /usr/local/bin/sops

RUN svn export https://github.com/yannh/kubernetes-json-schema/trunk/v${KUBERNETES_VERSION}-standalone /kubernetes-json-schemas/master-standalone

RUN curl -LO https://github.com/fluxcd/flux2/releases/download/v${FLUX_VERSION}/crd-schemas.tar.gz && \
    tar xf crd-schemas.tar.gz -C /kubernetes-json-schemas/master-standalone && \
    rm crd-schemas.tar.gz

COPY crds crds

RUN curl -LO https://raw.githubusercontent.com/yannh/kubeconform/master/scripts/openapi2jsonschema.py && \
    python3 openapi2jsonschema.py crds/**/*.yaml && \
    mv *.json /kubernetes-json-schemas/master-standalone

WORKDIR /build
