#!/usr/bin/env bash

# shellcheck disable=SC2148 # Tips depend on target shell

echo "::group::Build jo"
trap 'echo "::endgroup::"' EXIT
set -euxo pipefail

cd /tmp
git clone -q https://github.com/jpmens/jo
cd jo

autoreconf -i
./configure --prefix=/usr/local -q
make -j"$(nproc)" check
# installs into (empty) dirs under /usr/local: /bin, /share/man/man1,
#   /etc/bash_completion.d, /share/zsh/site-functions
make install
jo -v
