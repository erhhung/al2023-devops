#!/usr/bin/env bash

# shellcheck disable=SC2148 # Tips depend on target shell

echo "::group::Build Python 3.13"
trap 'echo "::endgroup::"' EXIT
set -euxo pipefail

cd /tmp
dnf install -y  openssl-devel bzip2-devel xz-devel libffi-devel \
  libuuid-devel gdbm-devel readline-devel tk-devel sqlite-devel
VER="3.13"
FTP="https://www.python.org/ftp/python"
# determine the latest patch version
ver=$(curl -s $FTP/ | sed -En 's/^.+href="('${VER/./\\.}'\..+)\/".+$/\1/p' | sort -Vr | head -1)
curl -fsL "$FTP/$ver/Python-$ver.tgz" | tar -xz
cd Python*
# https://docs.python.org/3/using/configure.html
./configure -q \
  --prefix=/usr/local \
  --enable-optimizations \
  --with-lto=full \
  --with-computed-gotos
make -sj"$(nproc)"
# installs into (empty) dirs under /usr/local: /bin, /lib, /share/man/man1
make altinstall

alternatives --install /usr/local/bin/python3 python3 /usr/local/bin/python$VER 1
alternatives --install /usr/local/bin/python  python  /usr/local/bin/python3    1
alternatives --list
hash -r
python3 -VV
python3 -m pip install -U --no-cache-dir --root-user-action=ignore pip
# must copy all new symlinks in /etc/alternatives into the final image
alternatives --install /usr/local/bin/pip3 pip3 /usr/local/bin/pip$VER 1
alternatives --install /usr/local/bin/pip  pip  /usr/local/bin/pip3    1
alternatives --list
hash -r
pip3 -V
