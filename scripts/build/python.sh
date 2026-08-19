#!/usr/bin/env bash

# shellcheck disable=SC2148 # Tips depend on target shell

VER=3.14
echo "::group::Build Python $VER"
trap 'echo "::endgroup::"' EXIT
set -euxo pipefail

cd /tmp
dnf install -y  openssl-devel bzip2-devel xz-devel libffi-devel \
  libuuid-devel gdbm-devel readline-devel tk-devel sqlite-devel \
  mpdecimal-devel
FTP="https://www.python.org/ftp/python"
# determine the latest patch version
ver=$(curl -s $FTP/ | sed -En 's/^.+href="('${VER/./\\.}'\..+)\/".+$/\1/p' | sort -Vr | head -1)
curl -fsL "$FTP/$ver/Python-$ver.tgz" | tar -xz
cd Python*

# https://docs.python.org/3/using/configure.html
./configure -q \
  --prefix=/usr/local \
  --disable-test-modules \
  --enable-optimizations \
  --with-lto=full \
  --with-computed-gotos
make -sj"$(nproc)" && strip python
# installs into (empty) dirs under /usr/local: /bin, /lib, /share/man/man1
make altinstall

BIN_DIR=/usr/local/bin
alternatives --list   | grep  -E  'pip|python' | \
  awk '{print $1,$3}' | xargs -rl alternatives --remove || true
alternatives --install $BIN_DIR/python3 python3 $BIN_DIR/python${VER} 1
alternatives --install $BIN_DIR/python  python  $BIN_DIR/python3      1
alternatives --list
hash -r && python3 -VV

python3 -m pip install -U --no-cache-dir --root-user-action=ignore pip
# must copy all new symlinks in /etc/alternatives into the final image
alternatives --install $BIN_DIR/pip3 pip3 $BIN_DIR/pip${VER} 1
alternatives --install $BIN_DIR/pip  pip  $BIN_DIR/pip3      1
alternatives --list
hash -r && pip3 -V
