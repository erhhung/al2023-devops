#!/usr/bin/env bash

# shellcheck disable=SC2148 # Tips depend on target shell

echo "::group::Install Docker BuildX and Compose"
trap 'echo "::endgroup::"' EXIT
set -euxo pipefail

PLUGIN_DIR="/root/.docker/cli-plugins"
mkdir -p $PLUGIN_DIR
alternatives --install $PLUGIN_DIR/docker-buildx  docker-buildx  /usr/local/bin/docker-buildx  1
alternatives --install $PLUGIN_DIR/docker-compose docker-compose /usr/local/bin/docker-compose 1
docker buildx  install
docker buildx  version
docker compose version
