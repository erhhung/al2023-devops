#!/usr/bin/env bash

# shellcheck disable=SC2148 # Tips depend on target shell
# shellcheck disable=SC2046 # Quote to prevent word splitting

echo "::group::Install infra tools"
trap 'echo "::endgroup::"' EXIT
set -euxo pipefail

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
  ansible jsonpatch kubernetes kubernetes-validate
rm -rf /root/.cache
export $(xargs < /etc/locale.conf)
ansible --version
