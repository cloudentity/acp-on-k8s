#!/bin/bash

# Use this script before 'make install-acp-stack' to add extra tenants.
# NOTE that after using make uninstall-acp, i had to delete the Service "timescale-config", before i could re-run install-acp-stack.

NUM=${1:-1}

cat <<EOT >> ../values/kube-acp-stack.yaml
      tenants:
EOT
for I in `seq 1 $NUM`
do
    cat <<EOT >> ../values/kube-acp-stack.yaml
        - id: tid-$I
          name: tid-$I
EOT
done

cat <<EOT >> ../values/kube-acp-stack.yaml
      servers:
EOT
for I in `seq 1 $NUM`
do
    cat <<EOT >> ../values/kube-acp-stack.yaml
        - id: default
          tenant_id: tid-$I
EOT
done
