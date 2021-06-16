#!/bin/bash
set -x
EXEC_PROFILE="$1"

update_snapshots() {
  mvn -U clean dependency:purge-local-repository install -f ./tests/pom.xml -pl acceptance -DskipTests -Dinclude=com.cloudentity.authorization.test
}

prepare() {
  PROFILE="$1"
  # shellcheck disable=SC2086
  mvn -B clean install -f ./tests/pom.xml -pl acceptance -DskipTests -P ${PROFILE}
}

start_grid() {
  docker-compose -f ./tests/acceptance/docker/docker-compose.yaml up -d
}

stop_grid() {
  # Subshell because of temporary current dir change
  (
    cd ./tests/acceptance/docker
    docker-compose down || (docker-compose kill && docker-compose rm)
    true
  )
}

clean_data() {
  git clean -fdx tests/
}

run_tests() {
  PROFILE="$1"
  ENV_URL="$2"
  BASE_URL=${ENV_URL} \
    COMMAND_BASE="authorization" \
    CONFIG_LOCATION="/opt/cloudentity/acp/reference.yaml,/opt/cloudentity/acp/config.yaml" \
    mvn -B test -f ./tests/pom.xml -pl acceptance -P "${PROFILE}" $ADDITIONAL_TEST_OPTIONS
  # cleanup
  TESTS_ERROR_CODE=$?
  if ((TESTS_ERROR_CODE != 0)); then
    mvn -q allure:report -f ./tests/pom.xml -pl acceptance -P "${PROFILE}"
    exit $TESTS_ERROR_CODE
  fi
}

run_web_tests() {
  PROFILE="$1"
  ENV_URL="$2"
  BASE_URL=${ENV_URL} \
    mvn -B test -f ./tests/pom.xml -pl acceptance -P ${PROFILE} $ADDITIONAL_TEST_OPTIONS
  # web cleanup
  TESTS_ERROR_CODE=$?
  if ((TESTS_ERROR_CODE != 0)); then
    docker logs standalone-chrome &>standalone-chrome.log
    mvn -q allure:report -f ./tests/pom.xml -pl acceptance -P ${PROFILE}
    exit $TESTS_ERROR_CODE
  fi
}

case "$EXEC_PROFILE" in
update)
  # Necessary for updating snapshots (dev version)
  update_snapshots
  ;;
rest)
  # Necessary for dynamic tests suite swapping
  prepare rest-api-tests "$2"
  run_tests rest-api-tests "$2"
  ;;
enforcement)
  # Necessary for dynamic tests suite swapping
  prepare enforcement "$2"
  run_tests enforcement "$2"
  ;;
web)
  # Start selenium grid on docker
  start_grid
  # Necessary for dynamic tests suite swapping
  prepare web "$2"
  run_web_tests web "$2"
  ;;
web-smoke)
  # Start selenium grid on docker
  start_grid
  # Necessary for dynamic tests suite swapping
  prepare web-smoke "$2"
  run_web_tests web-smoke "$2"
  ;;
clean-data)
  # Clean unneeded tests data
  clean_data
  ;;
clean-grid)
  # Stop selenium grid on docekr
  stop_grid
  ;;
*)
  echo "update admin developer web"
  exit
  ;;
esac
