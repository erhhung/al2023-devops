#!/usr/bin/env bash

# shellcheck disable=SC2148 # Tips depend on target shell
# shellcheck disable=SC2086 # Double quote prevent globbing
# shellcheck disable=SC2030 # Modification of var is local
# shellcheck disable=SC2031 # var was modified in subshell

echo "::group::Install Kubernetes tools"
trap 'echo "::endgroup::"' EXIT
set -euxo pipefail

# use the appropriate binaries for this multi-arch Docker image
ARCH=$(uname -m | sed -e 's/aarch64/arm64/' -e 's/x86_64/amd64/')

# install Kubectl: https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/
cd /usr/local/bin
REL="https://dl.k8s.io/release"
VER=$(curl -sL $REL/stable.txt)
curl -fsSLO "$REL/$VER/bin/linux/$ARCH"/kubectl
chmod +x kubectl
kubectl version --client

# install Kubeconform: https://github.com/yannh/kubeconform#installation
REL="https://github.com/yannh/kubeconform/releases/latest"
curl -fsSL "$REL/download/kubeconform-linux-${ARCH}.tar.gz" | \
  tar -xz -C /usr/local/bin --no-same-owner kubeconform
ln -s /usr/local/bin/kubeconform /usr/local/bin/kubectl-conform
kubectl conform -v

# install Krew: https://krew.sigs.k8s.io/docs/user-guide/setup/install/
cd /tmp
REL="https://github.com/kubernetes-sigs/krew/releases/latest"
KREW="krew-linux_${ARCH}"
curl -fsSL "$REL/download/$KREW.tar.gz" | tar -xz ./$KREW
./$KREW install krew
rm -f ./$KREW
# /root/.krew/bin is already in $PATH via Dockerfile ENV command
kubectl krew version

# install kubectl-grep: https://github.com/guessi/kubectl-grep#installation
kubectl krew install grep
kubectl grep version --short

# install kube-score: https://github.com/zegl/kube-score#installation
kubectl krew install score
if [ $ARCH == arm64 ]; then
  echo "Installing the proper $ARCH binary for kube-score"
  REL="https://github.com/zegl/kube-score/releases/latest"
  VER=$(curl -Is $REL | sed -En 's/^location:.+\/tag\/v(.+)\r$/\1/p')
  curl -fsSL "$REL/download/kube-score_${VER}_linux_${ARCH}.tar.gz" | \
    tar -C /root/.krew/store/score/* -xz
fi
kubectl score version

# install kind: https://kind.sigs.k8s.io/docs/user/quick-start#installation
cd /usr/local/bin
REL="https://github.com/kubernetes-sigs/kind/releases/latest"
curl -fsSLo kind "$REL/download/kind-linux-$ARCH"
chmod +x kind
kind --version

# install vCluster: https://www.vcluster.com/install
cd /usr/local/bin
REL="https://github.com/loft-sh/vcluster/releases/latest"
curl -fsSLo vcluster "$REL/download/vcluster-linux-$ARCH"
chmod +x vcluster
vcluster version

# install Helm: https://helm.sh/docs/intro/install/
REL="https://github.com/helm/helm/releases/latest"
VER=$(curl -Is $REL | sed -En 's/^location:.+\/tag\/(.+)\r$/\1/p')
curl -fsSL "https://get.helm.sh/helm-${VER}-linux-${ARCH}.tar.gz" | \
  tar -xz -C /usr/local/bin --no-same-owner --strip 1 "linux-$ARCH"/helm
helm version

# install helm-docs: https://github.com/norwoodj/helm-docs#installation
REL="https://github.com/norwoodj/helm-docs/releases/latest"
VER=$(curl -Is $REL | sed -En 's/^location:.+\/tag\/v(.+)\r$/\1/p')
arch=$(uname -m | sed -e 's/aarch64/arm64/') # must be x86_64 or arm64
curl -fsSL "$REL/download/helm-docs_${VER}_Linux_${arch}.tar.gz" | \
  tar -xz -C /usr/local/bin --no-same-owner helm-docs
helm-docs --version

# install Helm plugins
helm plugin install https://github.com/databus23/helm-diff
helm diff version
(
  cd /root/.local/share/helm/plugins
  REPO="https://github.com/codacy/helm-ssm"
  git clone -q $REPO
  cd helm-ssm
  REL="$REPO/releases/latest"
  # name must be *linux.tgz or *linux-arm.tgz
  ARCH=${ARCH/%amd*/} ARCH=${ARCH/%arm*/-arm}
  curl -fsSL "$REL/download/helm-ssm-linux${ARCH}.tgz" | tar -xz
  VER=$(curl -Is $REL | sed -En 's/^location:.+\/tag\/(.+)\r$/\1/p')
  sed -i "s/\"dev\"/\"$VER\"/" plugin.yaml
  helm ssm --help
)
helm plugin list
rm -rf /root/.cache

# install Helmfile: https://github.com/helmfile/helmfile#installation
REL="https://github.com/helmfile/helmfile/releases/latest"
VER=$(curl -Is $REL | sed -En 's/^location:.+\/tag\/v(.+)\r$/\1/p')
curl -fsSL "$REL/download/helmfile_${VER}_linux_${ARCH}.tar.gz" | \
  tar -xz -C /usr/local/bin --no-same-owner helmfile
helmfile --version

# install Argo CD: https://argo-cd.readthedocs.io/en/stable/cli_installation/
cd /usr/local/bin
REL="https://github.com/argoproj/argo-cd/releases/latest"
curl -fsSLo argocd "$REL/download/argocd-linux-$ARCH"
chmod +x argocd
argocd version --client --short

# install Argo Rollouts: https://argoproj.github.io/argo-rollouts/installation/
cd /usr/local/bin
REL="https://github.com/argoproj/argo-rollouts/releases/latest"
curl -fsSLo kubectl-argo-rollouts "$REL/download/kubectl-argo-rollouts-linux-$ARCH"
chmod +x kubectl-argo-rollouts
kubectl argo rollouts version --short
