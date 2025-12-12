#!/usr/bin/env bash

# dhrmi.sh: delete old images in Docker Hub
#
# USAGE: dhrmi.sh <repo> [date]
#  repo: <namespace>/<repository>
#  date: YYYY-MM[-DD]
#
# delete ALL untagged versions, and, if date is
# given, also delete tagged versions older than
# that date

set -eo pipefail

REPO=$1
DATE=$2

if [ ! "$REPO" ]; then
  echo "USAGE: dhrmi.sh <repo> [date]"
  echo " repo: <namespace>/<repository>"
  echo " date: YYYY-MM[-DD]"
  exit
fi
[[ "$REPO" == */* ]] || {
  echo >&2 "ERROR: repo must be <namespace>/<repository>."
  exit 1
}
[[ "$DATE" =~ ^([0-9]{4}-[0-9]{2}(-[0-9]{2})?)?$ ]] || {
  echo >&2 "ERROR: date must be YYYY-MM[-DD]."
  exit 1
}
[[ "$DOCKER_USERNAME" && "$DOCKER_ACCESS_TOKEN" ]] || {
  echo >&2 "ERROR: missing Docker Hub credentials:"
  echo >&2 "DOCKER_USERNAME & DOCKER_ACCESS_TOKEN"
  exit 1
}
command -v jq &> /dev/null || {
  echo >&2 "ERROR: please install jq CLI."
  exit 1
}
# pad date to full ISO form
TEMP="0000-01-01T00:00:00Z"
DATE+="${TEMP:${#DATE}}"

   RED='\x1B[31m'
LTBLUE='\x1B[94m'
 WHITE='\x1B[97m'
YELLOW='\x1B[33m'
 NOCLR='\x1B[0m'

CURL_ARGS=(-sSL -u "${DOCKER_USERNAME}:${DOCKER_ACCESS_TOKEN}")
base_url="https://hub.docker.com/v2/namespaces/${REPO/\//\/repositories\/}/tags"
next_url="$base_url?page_size=100"

while [[ "$next_url" == http* ]]; do
  resp=$(curl "${CURL_ARGS[@]}" "$next_url")

  # this script is incomplete because Docker Hub
  # API provides no way to query untagged images
done
