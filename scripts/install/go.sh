#!/usr/bin/env bash

# shellcheck disable=SC2148 # Tips depend on target shell
# shellcheck disable=SC2086 # Double quote prevent globbing
# shellcheck disable=SC2046 # Quote to prevent word splitting

echo "::group::Install Go 1.25"
trap 'echo "::endgroup::"' EXIT
set -euxo pipefail

dnf install -y golang
dnf clean all
rm -rf /var/log/* /var/cache/dnf
go version

# purge unused locales
export $(xargs < /etc/locale.conf)
localedef -i $LANGUAGE -f UTF-8 $LANGUAGE.UTF-8
find /usr/{lib,share}/locale/* -maxdepth 0 -type d -not -iname "$LANGUAGE*" -exec rm -rf {} \;
