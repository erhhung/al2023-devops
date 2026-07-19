#!/usr/bin/env bash

# shellcheck disable=SC2148 # Tips depend on target shell

echo "::group::Install development tools"
trap 'echo "::endgroup::"' EXIT
set -euxo pipefail

# use the appropriate binaries for this multi-arch Docker image
ARCH=$(uname -m | sed -e 's/aarch64/arm64/' -e 's/x86_64/amd64/')

# install Delta: https://github.com/dandavison/delta
REL="https://github.com/dandavison/delta/releases"
VER=$(curl -ILs "$REL/latest" | sed -En 's/^location:.+\/tag\/(.+)\r$/\1/p')
curl -fsSL "$REL/download/$VER/delta-$VER-$(uname -m)-unknown-linux-gnu.tar.gz" | \
  tar -xz -C /usr/local/bin --no-same-owner --strip 1 "*/delta"
delta --version

# install Bazelisk: https://github.com/bazelbuild/bazelisk#installation
REL="https://github.com/bazelbuild/bazelisk/releases"
VER=$(curl -ILs "$REL/latest" | sed -En 's/^location:.+\/tag\/v(.+)\r$/\1/p')
curl -fsSLo /usr/local/bin/bazel "$REL/download/v${VER}/bazelisk-linux-$ARCH"
chmod +x /usr/local/bin/bazel
bazel --version

# install Buildifier + Buildozer: https://github.com/bazelbuild/buildtools
REL="https://github.com/bazelbuild/buildtools/releases"
VER=$(curl -ILs "$REL/latest" | sed -En 's/^location:.+\/tag\/v(.+)\r$/\1/p')
for tool in buildifier buildozer; do
  curl -fsSLo /usr/local/bin/$tool "$REL/download/v${VER}/$tool-linux-$ARCH"
  chmod +x /usr/local/bin/$tool
done
buildifier -version
