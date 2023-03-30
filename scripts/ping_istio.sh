#!/bin/bash

# This script assumes that you have installed the istio-authorizer in multi-tenant authorizer mode,
# and set up ACP with with additional tenants. See add_tenants.sh in this directory to create the
# additional tenants when you make install-acp-stack.
#
# This script also assumes that you have installed the httpbin example and the sleep pod, as described in:
#
#   https://cloudentity.com/developers/howtos/enforcement/istio/
#
# There is a concise guide to setting this up, which also adds instructions how to deploy the istio-authorizer
# from a custom Docker image, in cloudentity/acp/cmd/istio/README.me.
#
# For each tenant, this script constructs a token with the claims tid and aid corresponding to the tenant,
# and then sends a request from the sleep pod that will be authorized (or not) by the istio-authorizer.
# The token's tid claim  will force the creation of an authorizer for that tenant in the istio-authorizer.
#
# Usage:
#
#   ping_istio.sh $NUM [ loop ]
#
# $NUM can be between 1 and the number of tenants you added with add_tenants.sh
# Add 'loop' if you want to cycle continuously, otherwise it will ping tenants tid-1 .. tid-$NUM once and exit.
#
NUM=${1:-1}
OPT=${2}

base64_encode()
{
	declare input=${1:-$(</dev/stdin)}
	# Use `tr` to URL encode the output from base64.
	printf '%s' "${input}" | base64 | tr -d '=' | tr '/+' '_-' | tr -d '\n'
}

SLEEP=`kubectl get pod -l app=sleep -o jsonpath={.items..metadata.name}`

while true
do
    for IX in `seq 1 $NUM`
    do
        tid=tid-$IX
        aid=default

        # This token only has to parse, it does not need to verify.
        TOKEN=$(base64_encode <<<'{"typ":"JWT","alg":"HS256"}').$(base64_encode <<<'{"tid":"'$tid'","aid":"'$aid'"}').ffff

        kubectl exec -it $SLEEP --container sleep -- curl -s -D - -H "Authorization: bearer $TOKEN" http://httpbin.default:80/anything > /dev/null
        echo -n .
    done
    if [ "$OPT" != "loop" ] ; then break ; fi
    echo loop
done
