#!/usr/bin/env bash

# shellcheck disable=SC2148 # Tips depend on target shell
# shellcheck disable=SC2178 # Variable was used as an array

echo "::group::Build tini"
trap 'echo "::endgroup::"' EXIT
set -euxo pipefail

cd /tmp
dnf install -y cmake glibc-static
git clone -q https://github.com/krallin/tini
cd tini

CFLAGS=(
  -DPR_SET_CHILD_SUBREAPER=36
  -DPR_GET_CHILD_SUBREAPER=37
)
export CFLAGS="${CFLAGS[*]}"
cmake .
make -sj"$(nproc)"
# installs into /usr/local/bin
PREFIX=/usr/local make install
tini --version
