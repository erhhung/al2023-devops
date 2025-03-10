#!/usr/bin/env bash

# shellcheck disable=SC2148 # Tips depend on target shell

echo "::group::Install Node.js 22"
trap 'echo "::endgroup::"' EXIT
set -euxo pipefail

curl -fsSL https://rpm.nodesource.com/setup_22.x | bash -
dnf install -y nodejs
dnf clean all
rm -rf /var/log/* /var/cache/dnf
npm install -g npm
node --version
npm  --version

HOME=/root
# https://docs.npmjs.com/cli/v9/using-npm/config
npm config set update-notifier false
npm config set loglevel warn
npm config set fund false
rm -rf /root/.npm
