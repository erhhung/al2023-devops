#!/usr/bin/env bash

# ghrmi.sh: delete old images in GitHub GHCR
#
# USAGE: ghrmi.sh <package> [date]
#  date: YYYY-MM[-DD]
#
# delete ALL untagged versions, and, if date is
# given, also delete tagged versions older than
# that date
#
# requires gh CLI to be installed and authenticated
# with delete:packages access to the given package
#
# https://docs.github.com/en/rest/packages/packages#get-a-package-for-the-authenticated-user
# https://docs.github.com/en/rest/packages/packages#list-package-versions-for-a-package-owned-by-the-authenticated-user
# https://docs.github.com/en/rest/packages/packages#delete-a-package-version-for-the-authenticated-user

set -eo pipefail

PACKAGE=$1
   DATE=$2

if [ ! "$PACKAGE" ]; then
  echo "USAGE: ghrmi.sh <package> [date]"
  echo " date: YYYY-MM[-DD]"
  exit
fi
[[ "$DATE" =~ ^([0-9]{4}-[0-9]{2}(-[0-9]{2})?)?$ ]] || {
  echo >&2 "ERROR: date must be YYYY-MM[-DD]."
  exit 1
}
command -v gh &> /dev/null || {
  echo >&2 "ERROR: please install gh CLI and log in."
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

HEADERS=(-H "Accept: application/vnd.github+json")
api_path="/user/packages/container/$PACKAGE"
# command will fail if package cannot be found
gh api "${HEADERS[@]}" "$api_path" > /dev/null

while read -r id cdate hash tags; do
  msg="${RED}DELETING: ${LTBLUE}[$cdate] ${WHITE}$hash"
  [ "$tags" ] && msg+=" ${YELLOW}($tags)"
  echo -e "$msg${NOCLR}"

  gh api -X DELETE "${HEADERS[@]}" "$api_path/versions/$id"
done < <(
  CLICOLOR=0 CLICOLOR_FORCE=0 \
  gh api "${HEADERS[@]}" "$api_path/versions?per_page=100" --paginate | \
    jq --arg date "$DATE" -r  'sort_by(.created_at) |
      .[] | .metadata.container.tags // [] as $tags |
      select(($tags | length == 0) or (.created_at < $date)) |
      "\(.id) \(.created_at[:10]) \(.name) \($tags | join(","))"'
)
