#!/usr/bin/env bash

# shellcheck disable=SC2148 # Tips depend on target shell

echo "::group::Install OCI image tools"
trap 'echo "::endgroup::"' EXIT
set -euxo pipefail

# use the appropriate binaries for this multi-arch Docker image
ARCH=$(uname -m | sed -e 's/aarch64/arm64/' -e 's/x86_64/amd64/')

# install Dive: https://github.com/wagoodman/dive#installation
REL="https://github.com/wagoodman/dive/releases/latest"
VER=$(curl -Is $REL | sed -En 's/^location:.+\/tag\/v(.+)\r$/\1/p')
curl -fsSL "$REL/download/dive_${VER}_linux_${ARCH}.tar.gz" | \
  tar -xz -C /usr/local/bin --no-same-owner dive
dive --version
(
  # install MinToolkit: https://github.com/mintoolkit/mint#installation
  REL="https://github.com/mintoolkit/mint/releases/latest"
  # name must be *linux.* or *linux_arm64.*
  ARCH=${ARCH/%amd*/} ARCH=${ARCH/arm/_arm}
  curl -fsSL "$REL/download/dist_linux${ARCH}.tar.gz" | \
    tar -xz -C /usr/local/bin --no-same-owner --strip 1 "dist_linux${ARCH}"/mint*
  mint --version
)

# runc and CNI plugins are required by buildah
# (CNI plugins are installed into /opt/cni/bin)
# https://github.com/containers/buildah/tree/main/install.md#system-requirements
dnf -y install runc cni-plugins
dnf clean all
rm -rf /var/log/* /var/cache/dnf
runc --version

# install containers-common package from Fedora
rpm -i "https://dl.fedoraproject.org/pub/fedora/linux/releases/41/Everything/$(
          uname -m)/os/Packages/c/containers-common-0.60.4-4.fc41.noarch.rpm" \
    --nosignature

# use the vfs storage driver to avoid "overlay is not supported
# over overlayfs" error in an already containerized environment;
# runroot & graphroot must also be set, or else mint will fail:
# https://github.com/containers/storage/tree/main/storage.conf
cat <<EOF > /etc/containers/storage.conf
[storage]
driver = "vfs"
runroot = "/run/containers/storage"
graphroot = "/var/lib/containers/storage"
EOF
