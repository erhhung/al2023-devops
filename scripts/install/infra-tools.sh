#!/usr/bin/env bash

# shellcheck disable=SC2148 # Tips depend on target shell
# shellcheck disable=SC2046 # Quote to prevent word splitting

echo "::group::Install infra tools"
trap 'echo "::endgroup::"' EXIT
set -euxo pipefail

# use the appropriate binaries for this multi-arch Docker image
ARCH=$(uname -m | sed -e 's/aarch64/arm64/' -e 's/x86_64/amd64/')

# install Terraform: https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli#install-terraform
dnf install -y dnf-plugins-core
dnf config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo
dnf install -y terraform
dnf clean all
rm -rf /var/log/* /var/cache/dnf
terraform --version

# install Ansible and dependencies for Kubernetes:
# https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html#pip-install
pip3 install --no-cache-dir --root-user-action=ignore \
  ansible ansible-compat ansible-runner ansible-lint   \
  toml bcrypt==4.0.1 passlib netaddr jsonpatch jmespath \
  kubernetes kubernetes-validate
rm -rf /root/.cache
export $(xargs < /etc/locale.conf)
ansible --version

# install wait4x: https://github.com/wait4x/wait4x
REL="https://github.com/wait4x/wait4x/releases"
VER=$(curl -Is "$REL/latest" | sed -En 's/^location:.+\/tag\/v(.+)\r$/\1/p')
curl -fsSL "$REL/download/v${VER}/wait4x-linux-$ARCH.tar.gz" | \
  tar -xz -C /usr/local/bin --no-same-owner wait4x
wait4x version
