#!/usr/bin/env bash

# shellcheck disable=SC2148 # Tips depend on target shell
# shellcheck disable=SC2086 # Double quote prevent globbing
# shellcheck disable=SC2046 # Quote to prevent word splitting

echo "::group::Install Linux utilities"
trap 'echo "::endgroup::"' EXIT
set -euxo pipefail

# use the appropriate binaries for this multi-arch Docker image
ARCH=$(uname -m | sed -e 's/aarch64/arm64/' -e 's/x86_64/amd64/')

# save the exact Amazon Linux release version
rpm -q system-release | sed -En 's/^.+-(2023.+)-.+$/\1/p' > /etc/dnf/vars/releasever
dnf check-update

# install common utilities (procps provides "free" command)
# perl-IPC-Run and perl-Time-HiRes are required by moreutils
dnf install -y git wget tar xz bzip2 gzip unzip man bc bash-completion \
  which findutils kmod iproute iputils dnsutils net-tools nmap gettext \
  procps pwgen sshpass openssl vim tmux perl-IPC-Run perl-Time-HiRes \
  glibc-locale-source glibc-langpack-en
dnf clean all
rm -rf /var/log/* /var/cache/dnf
alternatives --install /usr/local/bin/vi vi /usr/bin/vim 1
alternatives --list

# install tmux plugins: https://github.com/tmux-plugins/tpm#installation
TMUX_PLUGIN_MANAGER_PATH="/root/.tmux/plugins/tpm"
git clone -q https://github.com/tmux-plugins/tpm $TMUX_PLUGIN_MANAGER_PATH
# install requires previously copied .tmux.conf
$TMUX_PLUGIN_MANAGER_PATH/bin/install_plugins

# purge unused locales
export $(xargs < /etc/locale.conf)
localedef -i $LANGUAGE -f UTF-8 $LANGUAGE.UTF-8
find /usr/{lib,share}/locale/* -maxdepth 0 -type d -not -iname "$LANGUAGE*" -exec rm -rf {} \;

# install just: https://github.com/casey/just#pre-built-binaries
cd /tmp
REL="https://github.com/casey/just/releases"
VER=$(curl -Is "$REL/latest" | sed -En 's/^location:.+\/tag\/(.+)\r$/\1/p')
curl -fsSL "$REL/download/$VER/just-$VER-$(uname -m)-unknown-linux-musl.tar.gz" | \
  tar -xz --no-same-owner just* completions/*.bash
mv just       /usr/local/bin
mv ./*/*.bash /usr/local/etc/bash_completion.d
mv just.1     /usr/local/share/man/man1
rm -rf completions
just --version

install_bin() {
  cd /usr/local/bin
  local bin=$1 src=$2
  curl -fsSLo $bin $src
  chmod +x $bin
  $bin --version
}

# install sops: https://github.com/getsops/sops
REL="https://github.com/getsops/sops/releases"
VER=$(curl -Is "$REL/latest" | sed -En 's/^location:.+\/tag\/v(.+)\r$/\1/p')
(
  export SOPS_DISABLE_VERSION_CHECK=1
  install_bin sops "$REL/download/v${VER}/sops-v${VER}.linux.$ARCH"
)
# install jq: https://stedolan.github.io/jq
install_bin jq "https://github.com/stedolan/jq/releases/latest/download/jq-linux-$ARCH"
# install yq: https://github.com/mikefarah/yq
install_bin yq "https://github.com/mikefarah/yq/releases/latest/download/yq_linux_$ARCH"

EPEL="https://dl.fedoraproject.org/pub/epel"
rpm --import $EPEL/RPM-GPG-KEY-EPEL-9

install_rpms() {
  local pkg url
  for pkg in "$@"; do
    url="$EPEL/9/Everything/$(uname -m)/Packages/${pkg::1}/"
    url+=$(curl -sL $url | sed -En 's/^.+href="('${pkg}'-[0-9.]+[^"]+).+$/\1/p')
    rpm -i $url
  done
}

# install jsonnet: https://jsonnet.org/
install_rpms c4core rapidyaml jsonnet-libs jsonnet
jsonnet --version
