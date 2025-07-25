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
SET CLUSTER SETTING cloudstorage.http.custom_ca = '-----BEGIN CERTIFICATE-----
MIIFhDCCA2ygAwIBAgIUEDlrJ11poqjsV6TsGvn3BglMtKswDQYJKoZIhvcNAQEL
BQAwQjELMAkGA1UEBhMCVVMxFDASBgNVBAoMC0Nsb3VkZW50aXR5MR0wGwYDVQQD
DBRsb2NhbC5jbG91ZGVudGl0eS5pbzAeFw0yMTEwMTUxMjU0MjBaFw0zMTEwMTMx
MjU0MjBaMEIxCzAJBgNVBAYTAlVTMRQwEgYDVQQKDAtDbG91ZGVudGl0eTEdMBsG
A1UEAwwUbG9jYWwuY2xvdWRlbnRpdHkuaW8wggIiMA0GCSqGSIb3DQEBAQUAA4IC
DwAwggIKAoICAQDAdZXLuatbMGp0z686zkKSKJa1tPWcHLvGCH2IRx3qO+g2tl4s
2rYNkh1TKCyMaS61T0BqIJ94kTNRCRFqN3DWUBHGkNGynSWS1tTt0dX93Uazn8Rm
V3eCsnRI5hiWLIEm+VjWsU/41xRHckJpPTdjfKn5CfA+06iMumj0JAbGVubI+1Hz
rV7QKpCwKXywlNN8oU4XgBuYupcbMq9b/QZJUyWxumPBqBrxEFJDZajvCu9zeiUM
XyuQjCGk/RlebYJgwlmVgKCnPD3F8Lrk8QGcWaC/mOkoGqOjCUFJucA4V5ojBUY7
8ilt8mmRTpIKEm3X9BYdIhvOpl/FnioW+VDtoqEFZOD7TQcwTyR8HAG0FlWgkC46
a9ooGAV3eCB5S47BM3nqE7hDtAEqNhYScuW4WmLTrcc9dA2riQTR2knqcUv+CwNY
bBCOXn/O8PynHn02iQcMeY9k4D+douzl87yEZM87AwHxKjQjKkcNYThd18zY2np0
Op1zbI5XDoOgENJO3uBc2P8O1sij7ponAjdu9t4GZff/8QkvZYEPpwVzppERwG2H
3mk4uCLfByYH9jWAAhVvk2XL385vqsDt+RWmtn3VAafQBssTycA9qIvDI+FRxD5x
NMszHzTLpVP6AO5lmT5sBq5p4HCUGRsl8S6aKT1kw10lcvUijw46Uj/qkQIDAQAB
o3IwcDAdBgNVHQ4EFgQUIgVAAflT+rDg+GM2MnMJAn2xENcwHwYDVR0jBBgwFoAU
IgVAAflT+rDg+GM2MnMJAn2xENcwDwYDVR0TAQH/BAUwAwEB/zAdBgNVHSUEFjAU
BggrBgEFBQcDAQYIKwYBBQUHAwIwDQYJKoZIhvcNAQELBQADggIBABhn/8d2ijH6
YzIEXFBVeRJ5iQqPkuROlAnVAMKKxeTyLyj6o5StolhHcDml3IGn67eoawQII0wR
2PA+eVAiTwXxguDwCcZUbxgqfRFLWib4xTCQE3BzxmNSfF1wQGByOp+kUgrB5DLV
crvlZ7/Ee3ZTGMc/Rsxim+6K1FMTetwP/9sJAWT3VG7eYtZJbOWc/ny+tHACPfnm
zcGtgak6Nmn97acjM6JrZh74L8+fzFg/hflim/5DHhgEtyRLCFEGvg1jKPYZ/5zN
un05R0hFwzzAsq6uPFWNNw0D/pFG9o5JmnomvKHF8uHGfL84Errc5SMa8FGEGsLn
apw7S5VEh+RYfzao8J2ZdIJ5jWDsz62TX9Femyh4NLvczrY/nLUBWMyb7/MCYini
8jkn49siP8rj09K0KoRafa8KmSyJbSmwxj0xpDYGuhoulNdrsC9FQLA3qL3MsvGl
VVhtGob804GRKB7zd8Zjn7wzjtlnCfbzUYPdOyWkQXDKwAYvj33tXjrm0kBggFyd
amBTL0lEgJY7T8xdu7XDFbM2f734pmA9TQHKIHW2thke6KWZGpIhWpwmmzfOvtvs
3P6thCzbjUebdU3GXa780rGafWl7/yZz8iq/O2VHma0Co3nyvmLF0Kdrr8aNPbGy
VZGbDXlAN06jKx4HnMX1nbkIyTc0mu7k
-----END CERTIFICATE-----';

CREATE USER IF NOT EXISTS acp WITH PASSWORD null;
CREATE USER IF NOT EXISTS dev WITH PASSWORD 'p@ssw0rd!' NOSQLLOGIN;

CREATE DATABASE IF NOT EXISTS acp;
CREATE DATABASE IF NOT EXISTS spicedb;

GRANT admin TO acp;
GRANT admin TO dev;

CREATE SCHEDULE "acp" FOR BACKUP DATABASE "acp" INTO 's3://cockroachdb/acp?AWS_ACCESS_KEY_ID=admin&AWS_SECRET_ACCESS_KEY=p@ssw0rd!&AWS_ENDPOINT=minio.minio:9000' RECURRING '5 * * * *' WITH SCHEDULE OPTIONS 'ignore_existing_backups';
CREATE SCHEDULE "spicedb" FOR BACKUP DATABASE "spicedb" INTO 's3://cockroachdb/spicedb?AWS_ACCESS_KEY_ID=admin&AWS_SECRET_ACCESS_KEY=p@ssw0rd!&AWS_ENDPOINT=minio.minio:9000' RECURRING '35 * * * *' WITH SCHEDULE OPTIONS 'ignore_existing_backups';
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
