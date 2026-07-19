#!/usr/bin/env bash

# shellcheck disable=SC2148 # Tips depend on target shell

echo "::group::Install Java JDK 26"
trap 'echo "::endgroup::"' EXIT
set -euxo pipefail

# use the appropriate binaries for this multi-arch Docker image
ARCH=$(uname -m | sed -e 's/aarch64/arm64/' -e 's/x86_64/amd64/')

# https://docs.aws.amazon.com/corretto/latest/corretto-26-ug/amazon-linux-install.html
dnf install -y java-26-amazon-corretto-devel
dnf clean all
rm -rf /var/log/* /var/cache/dnf
java --version

# install Maven: https://maven.apache.org/download.cgi
REL="https://github.com/apache/maven/releases"
VER=$(curl -ILs "$REL/latest" | sed -En 's/^location:.+\/tag\/.+-(.+)\r$/\1/p')
REL="https://dlcdn.apache.org/maven/maven-${VER%%.*}"
mkdir -p /usr/local/maven
curl -fsSL "$REL/$VER/binaries/apache-maven-$VER-bin.tar.gz" | \
  tar -xz -C /usr/local/maven --no-same-owner --strip 1 "apache-maven-$VER"
# /usr/local/maven/bin is already in $PATH via Dockerfile ENV command
mvn --version

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
