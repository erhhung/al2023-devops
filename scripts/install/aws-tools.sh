#!/usr/bin/env bash

# shellcheck disable=SC2148 # Tips depend on target shell

echo "::group::Install AWS tools"
trap 'echo "::endgroup::"' EXIT
set -euxo pipefail

# install AWS CLI v2: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html
cd /tmp
curl -fsSLo awscliv2.zip "https://awscli.amazonaws.com/awscli-exe-linux-$(uname -m).zip"
unzip -q awscliv2.zip
./aws/install
rm -rf aws awscliv2.zip
aws --version

# install AWS CDK and CDK8s: https://docs.aws.amazon.com/cdk/v2/guide/getting_started.html
npm install -g aws-cdk cdk8s-cli
cdk   --version
cdk8s --version
rm -rf /root/.npm

# install Mountpoint for S3: https://github.com/awslabs/mountpoint-s3#getting-started
dnf install -y fuse-libs
dnf clean all
rm -rf /var/log/* /var/cache/dnf
REL="https://s3.amazonaws.com/mountpoint-s3-release/latest"
ARCH=$(uname -m | sed 's/aarch64/arm64/') # must be x86_64 or arm64
curl -fsSL "$REL/$ARCH/mount-s3.tar.gz" | \
  tar -xz -C /usr/local/bin --no-same-owner --strip 2 ./bin
mount-s3 --version
