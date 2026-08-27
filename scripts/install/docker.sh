#!/usr/bin/env bash

# shellcheck disable=SC2148 # Tips depend on target shell

echo "::group::Install Docker BuildX and Compose"
trap 'echo "::endgroup::"' EXIT
set -euxo pipefail

BIN_DIR=/usr/local/bin
strip -s $BIN_DIR/docker*

PLUGIN_DIR=/root/.docker/cli-plugins
mkdir -p $PLUGIN_DIR
alternatives --install $PLUGIN_DIR/docker-buildx  docker-buildx  $BIN_DIR/docker-buildx  1
alternatives --install $PLUGIN_DIR/docker-compose docker-compose $BIN_DIR/docker-compose 1
# install is deprecated
# docker buildx install
docker buildx  version
docker compose version
