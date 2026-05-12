#!/usr/bin/env bash

# shellcheck disable=SC2148 # Tips depend on target shell

echo "::group::Install Java JDK 26"
trap 'echo "::endgroup::"' EXIT
set -euxo pipefail

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
