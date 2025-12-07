#!/usr/bin/env bash

# shellcheck disable=SC2148 # Tips depend on target shell
# shellcheck disable=SC2086 # Double quote prevent globbing
# shellcheck disable=SC2046 # Quote to avoid word splitting
# shellcheck disable=SC2006 # Prefer $(...) over legacy `...`
# shellcheck disable=SC2207 # Prefer mapfile to split output

echo "::group::Install Go 1.25"
trap 'echo "::endgroup::"' EXIT
set -euxo pipefail

# use the appropriate binaries for this multi-arch Docker image
ARCH=$(uname -m | sed -e 's/aarch64/arm64/' -e 's/x86_64/amd64/')

# Go 1.25 may not be available in Amazon package repository
RPM=$(dnf repoquery --latest-limit=1 -s golang 2> /dev/null)

if [[ "$RPM" == golang-1.25* ]]; then
  # package installs under /usr/bin
  dnf install -y golang
  dnf clean all
  rm -rf /var/log/* /var/cache/dnf
else
  # install manually under /usr/local/go/bin: https://go.dev/doc/install
  VER=$(v=(`curl -s "https://go.dev/VERSION?m=text"`); echo ${v#go})
  curl -fsSL "https://go.dev/dl/go${VER}.linux-$ARCH.tar.gz" | \
    tar -xz -C /usr/local --no-same-owner
  for bin in /usr/local/go/bin/*; do
    ln -s $bin /usr/local/bin/
  done
fi
go version

# purge unused locales
export $(xargs < /etc/locale.conf)
localedef -i $LANGUAGE -f UTF-8 $LANGUAGE.UTF-8
find /usr/{lib,share}/locale/* -maxdepth 0 -type d \
  -not -iname "$LANGUAGE*" -exec rm -rf {} \;
