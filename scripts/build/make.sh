#!/usr/bin/env bash

# shellcheck disable=SC2148 # Tips depend on target shell

echo "::group::Build GNU Make"
trap 'echo "::endgroup::"' EXIT
set -euxo pipefail

cd /tmp
# https://ftp.gnu.org/gnu/make
VER=4.4.1 # latest available
FTP="https://ftp.gnu.org/gnu/make"
curl -fsL $FTP/make-$VER.tar.lz | tar -x --lzip

cd make*
./configure --prefix=/usr/local -q
make -sj"$(nproc)" && strip make
# installs into (empty) dirs under /usr/local: /bin, /include,
#   /share/info, /share/locale, /share/man/man1,
./make install
hash -r && make --version
