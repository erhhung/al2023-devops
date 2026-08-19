#!/usr/bin/env bash

# shellcheck disable=SC2148 # Tips depend on target shell

echo "::group::Build moreutils"
trap 'echo "::endgroup::"' EXIT
set -euxo pipefail

cd /tmp
dnf install -y libxslt docbook-xsl
git clone -q git://git.joeyh.name/moreutils
cd moreutils

# don't replace installed GNU parallel
sed -i 's/parallel[^ ]* //' Makefile
DOCBOOKXSL=/usr/share/sgml/docbook/xsl-stylesheets make -sj"$(nproc)"
sed -En 's/BINS=(.+)/\1/p' Makefile | xargs strip
# installs into (empty) dirs under
# /usr/local: /bin, /share/man/man1
PREFIX=/usr/local make install 2> /dev/null
# "chronic" requires perl-IPC-Run
# "ts" requires perl-Time-HiRes
sponge -h
