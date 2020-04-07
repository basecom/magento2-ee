#!/bin/bash
# Shop System Plugins:
# - Terms of Use can be found under:
# https://github.com/wirecard/magento2-ee/blob/master/_TERMS_OF_USE
# - License can be found under:
# https://github.com/wirecard/magento2-ee/blob/master/LICENSE
set -e # Exit with nonzero exit code if anything fails

set -a
source .env
set +a

for ARGUMENT in "$@"; do
  KEY=$(echo "${ARGUMENT}" | cut -f1 -d=)
  VALUE=$(echo "${ARGUMENT}" | cut -f2 -d=)

  case "${KEY}" in
  NGROK_URL) NGROK_URL=${VALUE} ;;
  GIT_BRANCH) GIT_BRANCH=${VALUE} ;;
  TRAVIS_PULL_REQUEST) TRAVIS_PULL_REQUEST=${VALUE} ;;
  SHOP_SYSTEM) SHOP_SYSTEM=${VALUE} ;;
  SHOP_SYSTEM_CONTAINER_NAME) SHOP_SYSTEM_CONTAINER_NAME=${VALUE} ;;
  SHOP_VERSION) SHOP_VERSION=${VALUE} ;;
  BROWSERSTACK_USER) BROWSERSTACK_USER=${VALUE} ;;
  BROWSERSTACK_ACCESS_KEY) BROWSERSTACK_ACCESS_KEY=${VALUE} ;;
  *) ;;
  esac
done

# if tests triggered by PR, use different Travis variable to get branch name
if [ "${TRAVIS_PULL_REQUEST}" != "false" ]; then
  export GIT_BRANCH="${TRAVIS_PULL_REQUEST_BRANCH}"
fi

# find out test group to be run
if [[ $GIT_BRANCH =~ ${PATCH_RELEASE} ]]; then
  TEST_GROUP="${PATCH_RELEASE}"
elif [[ $GIT_BRANCH =~ ${MINOR_RELEASE} ]]; then
  TEST_GROUP="${MINOR_RELEASE}"
# run all tests in nothing else specified
else
  TEST_GROUP="major"
#  TEST_GROUP="${MAJOR_RELEASE}"
fi

#install codeception and it's dependencies
# we cannot use codeception container here because UI tests need to execute docker commands in
# magento2 container (cleaning cache and running cron jobs)

#rm -rf composer.lock
#docker run --rm -it --volume $(pwd):/app prooph/composer:7.2 require codeception/codeception --dev
#docker run --rm -it --volume $(pwd):/app prooph/composer:7.2 require codeception/module-webdriver --dev
#docker run --rm -it --volume $(pwd):/app prooph/composer:7.2 require codeception/module-asserts --dev
#docker run --rm -it --volume $(pwd):/app prooph/composer:7.2 require codeception/module-db --dev

# run tests
#docker run --rm -it --volume $(pwd):/app prooph/composer:7.2 require wirecard/shopsystem-ui-testsuite:dev-master
export SHOP_SYSTEM="${SHOP_SYSTEM}"
export SHOP_URL="${NGROK_URL}"
export SHOP_VERSION="${SHOP_VERSION}"
export SHOP_SYSTEM_CONTAINER_NAME="${SHOP_SYSTEM_CONTAINER_NAME}"
export EXTENSION_VERSION="${GIT_BRANCH}"
export DB_HOST="${MYSQL_HOST}"
export DB_NAME="${MYSQL_DATABASE}"
export DB_USER="${MYSQL_USER}"
export DB_PASSWORD="${MYSQL_PASSWORD}"
export BROWSERSTACK_USER="${BROWSERSTACK_USER}"
export BROWSERSTACK_ACCESS_KEY="${BROWSERSTACK_ACCESS_KEY}"

vendor/bin/codecept run   acceptance \
  -g "${TEST_GROUP}" -g "${SHOP_SYSTEM}" \
  --env ci --html --xml
