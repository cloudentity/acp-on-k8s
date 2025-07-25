#!/bin/bash

provisionCluster() {
  while true; do
    /cockroach/cockroach sql \
      --certs-dir=/client-certs-root/ \
      --host cockroachdb-local-public.cockroachdb-local \
      --execute="
SET CLUSTER SETTING kv.rangefeed.enabled = 'true';
SET CLUSTER SETTING server.shutdown.connection_wait = '240';
SET CLUSTER SETTING server.shutdown.drain_wait = '30';
SET CLUSTER SETTING server.shutdown.query_wait = '10';
SET CLUSTER SETTING server.shutdown.lease_transfer_wait = '5';

CREATE USER IF NOT EXISTS acp WITH PASSWORD null;
CREATE USER IF NOT EXISTS dev WITH PASSWORD 'p@ssw0rd!' NOSQLLOGIN;

CREATE DATABASE IF NOT EXISTS acp;
CREATE DATABASE IF NOT EXISTS spicedb;

GRANT admin TO acp;
GRANT admin TO dev;
"
    local exitCode="$?"

    if [[ "$exitCode" == "0" ]]
      then break
    fi

    sleep 5
  done

  echo "Provisioning completed successfully"
}

provisionCluster;
