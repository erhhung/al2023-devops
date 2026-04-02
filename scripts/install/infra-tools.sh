#!/usr/bin/env bash

# shellcheck disable=SC2148 # Tips depend on target shell
# shellcheck disable=SC2046 # Quote to avoid word splitting
# shellcheck disable=SC2086 # Double quote prevent globbing

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
ansible --version

# install Ansible AWX CLI using system
# Python 3.9 (must be <= Python 3.12):
# https://github.com/ansible/awx/tree/devel/INSTALL.md#installing-the-awx-cli

# awxkit depends on pkg_resources, which was removed
# in setuptools==81, so must constrain setuptools<81:
# https://github.com/pypa/setuptools/issues/3085
# https://stackoverflow.com/a/79886564/347685
echo "setuptools<81" > /tmp/constraints.txt
# also include package `jq` to allow `--conf.format jq`
/usr/bin/pipx install awxkit --python /usr/bin/python3 \
  --pip-args "--constraint /tmp/constraints.txt jq"

# patch installed scripts to suppress
# pkg_resources is deprecated warning
for cli in awx akit; do
  bin=$(which $cli)
  grep -q filterwarnings $bin || \
    sed -i '/import sys/a\
\
import warnings # ignore UserWarning: pkg_resources is deprecated...\
warnings.filterwarnings("ignore", category=UserWarning, module="awxkit")\
' $bin
done
# pipx installs under ~/.local/bin, which
# is already in $PATH via Dockerfile ENV
awx --version

# install wait4x: https://github.com/wait4x/wait4x
REL="https://github.com/wait4x/wait4x/releases"
VER=$(curl -Is "$REL/latest" | sed -En 's/^location:.+\/tag\/v(.+)\r$/\1/p')
curl -fsSL "$REL/download/v${VER}/wait4x-linux-$ARCH.tar.gz" | \
  tar -xz -C /usr/local/bin --no-same-owner wait4x
wait4x version
