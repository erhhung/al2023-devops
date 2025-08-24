#!/usr/bin/env bash

# shellcheck disable=SC2148 # Tips depend on target shell

echo "::group::Build skopeo"
trap 'echo "::endgroup::"' EXIT
set -euxo pipefail

cd /tmp
# https://github.com/containers/skopeo/tree/main/install.md#building-from-source
dnf install -y golang gpgme-devel libassuan-devel

# Amazon Linux doesn't have btrfs-progs-devel
# package, so we need to build it from source
command -v btrfs &> /dev/null || (

  dnf install -y python3-devel e2fsprogs-devel \
    libblkid-devel libuuid-devel libudev-devel lzo-devel
  git clone git://git.kernel.org/pub/scm/linux/kernel/git/kdave/btrfs-progs.git
  cd btrfs-progs

  ./autogen.sh
  # install into /usr instead of default /usr/local
  # because we don't want to pollute target dirs of
  # the "builder" image with non-essential packages
  ./configure --prefix=/usr --disable-documentation -q
  make -sj"$(nproc)"
  make install
)
git clone https://github.com/containers/skopeo.git
cd skopeo

# set app version to non-dev release
sed -Ei 's/^(.+Version[^-]+).+$/\1"/' ./version/version.go
export DISABLE_DOCS=1
make -sj"$(nproc)"
# installs into (empty) dirs under /usr/local: /bin,
#   /share/bash-completion/completions, /share/zsh/site-functions
make install && rm -rf /usr/local/share/fish
skopeo --version
