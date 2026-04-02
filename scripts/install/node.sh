#!/usr/bin/env bash

# shellcheck disable=SC2148 # Tips depend on target shell

echo "::group::Install Node.js 24"
trap 'echo "::endgroup::"' EXIT
set -euxo pipefail

# https://nodesource.com/products/distributions
curl -fsSL https://rpm.nodesource.com/setup_24.x | bash -
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

# install pnpm: https://pnpm.io/installation#on-posix-systems
curl -fsSL https://get.pnpm.io/install.sh | sh -
# $PNPM_HOME and $PATH are already set by
# Dockerfile ENV, so no need for .bashrc
rm -f /root/.bashrc
pnpm --version
