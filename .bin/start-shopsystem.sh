#!/bin/bash
# Shop System Plugins:
# - Terms of Use can be found under:
# https://github.com/wirecard/magento2-ee/blob/master/_TERMS_OF_USE
# - License can be found under:
# https://github.com/wirecard/magento2-ee/blob/master/LICENSE

set -e
set -a
source .env

for ARGUMENT in "$@"; do
  KEY=$(echo "${ARGUMENT}" | cut -f1 -d=)
  VALUE=$(echo "${ARGUMENT}" | cut -f2 -d=)

  case "${KEY}" in
  NGROK_URL) NGROK_URL=${VALUE} ;;
  SHOP_VERSION) SHOP_VERSION=${VALUE} ;;
  TRAVIS_PULL_REQUEST) TRAVIS_PULL_REQUEST="${VALUE}" ;;
  TRAVIS_PULL_REQUEST_BRANCH) TRAVIS_PULL_REQUEST_BRANCH="${VALUE}" ;;
  TRAVIS_BRANCH) TRAVIS_BRANCH="${VALUE}" ;;
  USE_SPECIFIC_EXTENSION_RELEASE) USE_SPECIFIC_EXTENSION_RELEASE=${VALUE} ;;
  SPECIFIC_RELEASED_SHOP_EXTENSION_VERSION) SPECIFIC_RELEASED_SHOP_EXTENSION_VERSION=${VALUE} ;;
  *) ;;
  esac
done

EXTENSION_VERSION="dev-master"
# find out which shop extension vesion will be used for tests
# if tests triggered by PR, use extension version (branch) which originated PR
if [ "${TRAVIS_PULL_REQUEST}" != "false" ]; then
    EXTENSION_VERSION="dev-${TRAVIS_PULL_REQUEST_BRANCH}"
# this means we want to test with latest released extension version
elif [ "${USE_SPECIFIC_EXTENSION_RELEASE}" == "1" ]; then
# get latest released extension version
    EXTENSION_VERSION="${SPECIFIC_RELEASED_SHOP_EXTENSION_VERSION}"
# otherwise use version from current branch
else
    EXTENSION_VERSION="dev-${TRAVIS_BRANCH}"
fi
echo "SHOP_VERSION=${SHOP_VERSION}"

docker-compose build --build-arg MAGENTO_VERSION="${SHOP_VERSION}" web
docker-compose up -d
sleep 30
docker-compose ps

echo "NGROK_URL = $NGROK_URL"
while ! $(curl --output /dev/null --silent --head --fail "${NGROK_URL}"); do
    echo "Waiting for docker container to initialize"
    ((c++)) && ((c == 50)) && break
    sleep 5
done

# install magento shop
docker-compose exec web install-magento.sh
docker-compose exec web install-sampledata.sh

# install wirecard magento2 plugin
docker-compose exec web composer require wirecard/magento2-ee:"${EXTENSION_VERSION}"
docker-compose exec web cp /var/www/html/vendor/wirecard/magento2-ee/.bin/test-crontab.xml /var/www/html/vendor/wirecard/magento2-ee/etc/crontab.xml
docker-compose exec web php bin/magento setup:upgrade
docker-compose exec web php bin/magento setup:di:compile
#this gives the shop time to init
curl "$NGROK_URL" --head
sleep 30
curl "$NGROK_URL" --head

# start polling
docker-compose exec web service cron start

# clean cache to activate payment method
docker-compose exec web php bin/magento cache:clean
docker-compose exec web php bin/magento cache:flush
#docker-compose exec web php bin/magento cache:disable db_ddl collections config
docker-compose exec web php bin/magento cache:disable config

echo "\nModify File Permissions To Load CSS!\n"
docker-compose exec web bash -c "chmod -R 777 ./"
sleep 60
