#!/usr/bin/env bash

# shellcheck disable=SC2148 # Tips depend on target shell

echo "::group::Build GNU parallel"
trap 'echo "::endgroup::"' EXIT
set -euxo pipefail

cd /tmp
# VER=latest
VER=20260522 # last working version
FTP="https://ftp.gnu.org/gnu/parallel"
curl -fsL $FTP/parallel-$VER.tar.bz2 | tar -xj

# safer to clone the Git repo as the latest
# tarball is sometimes missing or corrupted
# GIT="https://https.git.savannah.gnu.org/git/parallel.git"
# git clone -q $GIT
cd parallel*

autoreconf --install -W gnu
./configure --prefix=/usr/local -q
make -sj"$(nproc)"
# installs into (empty) dirs under /usr/local: /bin, /share/man/man1,
#   /share/bash-completion/completions, /share/zsh/site-functions
make install
echo "will cite" | parallel --citation &> /dev/null
parallel --version
