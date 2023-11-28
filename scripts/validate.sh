#!/usr/bin/env bash

set -o errexit

# mirror kustomize-controller build options
export kustomize_flags="--load-restrictor=LoadRestrictionsNone"
export kustomize_config="kustomization.yaml"

eval_kustomization() {
  file=$1

  echo "INFO - Validating kustomization ${file/%$kustomize_config/}"
  kustomize build "${file/%$kustomize_config/}" $kustomize_flags |
    kubeconform -skip CustomResourceDefinition --schema-location=/kubernetes-json-schemas/

  if [[ ${PIPESTATUS[0]} != 0 ]]; then
    echo "ERROR - Validation failed for kustomization ${file/%$kustomize_config/}"
    exit 1
  fi
}
export -f eval_kustomization

find . -not -path './charts/*' -type f -name '*.yaml' | parallel --halt now,fail=1 "yq eval 'true' {} > /dev/null || echo \"Eval failed for {}\" | grep -v \"true\" | false"
find . -not -path './charts/*' -type f -name ${kustomize_config} | parallel --halt now,fail=1 eval_kustomization
