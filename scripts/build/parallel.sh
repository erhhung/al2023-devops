#!/usr/bin/env bash

# shellcheck disable=SC2148 # Tips depend on target shell

echo "::group::Build GNU parallel"
trap 'echo "::endgroup::"' EXIT
set -euxo pipefail

cd /tmp
FTP="https://ftp.gnu.org/gnu/parallel"
curl -fsL $FTP/parallel-latest.tar.bz2 | tar -xj
cd parallel*

./configure --prefix=/usr/local -q
make -sj"$(nproc)"
# installs into (empty) dirs under /usr/local: /bin, /share/man/man1,
#   /share/bash-completion/completions, /share/zsh/site-functions
make install
echo "will cite" | parallel --citation &> /dev/null
parallel --version
