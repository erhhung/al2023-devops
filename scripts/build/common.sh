#!/usr/bin/env bash

# shellcheck disable=SC2148 # Tips depend on target shell

echo "::group::Install common build tools"
trap 'echo "::endgroup::"' EXIT
set -euxo pipefail

dnf update
dnf group install -y "Development Tools"
