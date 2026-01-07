#!/usr/bin/env bash

# shellcheck disable=SC2148 # Tips depend on target shell
# shellcheck disable=SC2086 # Double quote prevent globbing
# shellcheck disable=SC2206 # Quote to avoid word splitting
# shellcheck disable=SC2030 # Modification of var is local
# shellcheck disable=SC2031 # var was modified in subshell

echo "::group::Install Kubernetes tools"
trap 'echo "::endgroup::"' EXIT
set -exo pipefail

# use the appropriate binaries for this multi-arch Docker image
ARCH=$(uname -m | sed -e 's/aarch64/arm64/' -e 's/x86_64/amd64/')

# install Kubectl: https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/
cd /usr/local/bin
REL="https://dl.k8s.io/release"
VER=$(curl -sL $REL/stable.txt)
curl -fsSLO "$REL/$VER/bin/linux/$ARCH"/kubectl
chmod +x kubectl
kubectl version --client

# create an empty kubeconfig file
kubectl config set clusters.local.server https://127.0.0.1:6443
kubectl config delete-cluster local

# install Kubeconform: https://github.com/yannh/kubeconform#installation
REL="https://github.com/yannh/kubeconform/releases"
VER=$(curl -Is "$REL/latest" | sed -En 's/^location:.+\/tag\/v(.+)\r$/\1/p')
curl -fsSL "$REL/download/v${VER}/kubeconform-linux-$ARCH.tar.gz" | \
  tar -xz -C /usr/local/bin --no-same-owner kubeconform
ln -s /usr/local/bin/kubeconform /usr/local/bin/kubectl-conform
kubectl conform -v

# install Krew: https://krew.sigs.k8s.io/docs/user-guide/setup/install/
cd /tmp
REL="https://github.com/kubernetes-sigs/krew/releases"
VER=$(curl -Is "$REL/latest" | sed -En 's/^location:.+\/tag\/v(.+)\r$/\1/p')
KREW="krew-linux_${ARCH}"
# suppress tar: Ignoring unknown extended header
# keyword 'LIBARCHIVE.xattr.com.apple.provenance'
curl -fsSL "$REL/download/v${VER}/$KREW.tar.gz" | \
  tar -xz ./$KREW 2> /dev/null
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
  REL="https://github.com/zegl/kube-score/releases"
  VER=$(curl -Is "$REL/latest" | sed -En 's/^location:.+\/tag\/v(.+)\r$/\1/p')
  curl -fsSL "$REL/download/v${VER}/kube-score_${VER}_linux_${ARCH}.tar.gz" | \
    tar -xz -C /root/.krew/store/score/*
fi
kubectl score version

# install Kustomize: https://kubectl.docs.kubernetes.io/installation/kustomize/binaries
REL="https://github.com/kubernetes-sigs/kustomize/releases"
VER=$(curl -Is "$REL/latest" | sed -En 's/^location:.+\/tag\/kustomize\/v(.+)\r$/\1/p')
curl -fsSL "$REL/download/kustomize/v${VER}/kustomize_v${VER}_linux_${ARCH}.tar.gz" | \
  tar -xz -C /usr/local/bin --no-same-owner kustomize
kustomize version

# install Helm: https://helm.sh/docs/intro/install
REL="https://github.com/helm/helm/releases"
VER=$(curl -Is "$REL/latest" | sed -En 's/^location:.+\/tag\/v(.+)\r$/\1/p')
curl -fsSL "https://get.helm.sh/helm-v${VER}-linux-$ARCH.tar.gz" | \
  tar -xz -C /usr/local/bin --no-same-owner --strip 1 "linux-$ARCH"/helm
helm version

# install helm-docs: https://github.com/norwoodj/helm-docs#installation
REL="https://github.com/norwoodj/helm-docs/releases"
VER=$(curl -Is "$REL/latest" | sed -En 's/^location:.+\/tag\/v(.+)\r$/\1/p')
arch=$(uname -m | sed -e 's/aarch64/arm64/') # must be x86_64 or arm64
curl -fsSL "$REL/download/v${VER}/helm-docs_${VER}_Linux_${arch}.tar.gz" | \
  tar -xz -C /usr/local/bin --no-same-owner helm-docs
helm-docs --version

# install Helm plugins
install_plugin() {
  local repo=$1 ver=$2 tgz=$3
  [ "$ver" ] || ver=$(
    curl -Is "$repo/releases/latest" | sed -En 's/^location:.+\/tag\/v(.+)\r$/\1/p'
  )
  local args=(--verify=false)
  if [ "$tgz" ]; then
    args+=("$repo/releases/download/v${ver}/${tgz//=VER=/$ver}")
  else
    args+=($repo --version $ver)
  fi
  helm plugin install "${args[@]}"
}

install_plugin https://github.com/aslafy-z/helm-git
# apply patch to fix invalid `helm version` command
sed -Ei 's/version -c/version/' $HELM_PLUGINS/helm-git/helm-git-plugin.sh

install_plugin https://github.com/databus23/helm-diff
helm diff version

# https://github.com/jkroepke/helm-secrets/wiki/Installation
install_plugin https://github.com/jkroepke/helm-secrets "" secrets-=VER=.tgz
install_plugin https://github.com/jkroepke/helm-secrets "" secrets-getter-=VER=.tgz
install_plugin https://github.com/jkroepke/helm-secrets "" secrets-post-renderer-=VER=.tgz
helm secrets --version | head -1
(
  cd /root/.local/share/helm/plugins
  REPO="https://github.com/codacy/helm-ssm"
  git clone -q $REPO
  cd helm-ssm
  REL="$REPO/releases"
  VER=$(curl -Is "$REL/latest" | sed -En 's/^location:.+\/tag\/(.+)\r$/\1/p')
  # name must be *linux.tgz or *linux-arm.tgz
  arch=${ARCH/%amd*/} arch=${arch/%arm*/-arm}
  curl -fsSL "$REL/download/$VER/helm-ssm-linux${arch}.tgz" | tar -xz
  sed -i "s/\"dev\"/\"$VER\"/" plugin.yaml
  helm ssm --help
)
helm plugin list
rm -rf /root/.cache

# install Helmfile: https://github.com/helmfile/helmfile#installation
REL="https://github.com/helmfile/helmfile/releases"
VER=$(curl -Is "$REL/latest" | sed -En 's/^location:.+\/tag\/v(.+)\r$/\1/p')
curl -fsSL "$REL/download/v${VER}/helmfile_${VER}_linux_${ARCH}.tar.gz" | \
  tar -xz -C /usr/local/bin --no-same-owner helmfile
helmfile --version

# install vals: https://github.com/helmfile/vals#installation
REL="https://github.com/helmfile/vals/releases"
VER=$(curl -Is "$REL/latest" | sed -En 's/^location:.+\/tag\/v(.+)\r$/\1/p')
curl -fsSL "$REL/download/v${VER}/vals_${VER}_linux_${ARCH}.tar.gz" | \
  tar -xz -C /usr/local/bin --no-same-owner vals
vals version

# install Argo CD: https://argo-cd.readthedocs.io/en/stable/cli_installation/
cd /usr/local/bin
REL="https://github.com/argoproj/argo-cd/releases"
VER=$(curl -Is "$REL/latest" | sed -En 's/^location:.+\/tag\/v(.+)\r$/\1/p')
curl -fsSLo argocd "$REL/download/v${VER}/argocd-linux-$ARCH"
chmod +x argocd
argocd version --client --short

# install Argo Rollouts: https://argoproj.github.io/argo-rollouts/installation/
cd /usr/local/bin
REL="https://github.com/argoproj/argo-rollouts/releases"
VER=$(curl -Is "$REL/latest" | sed -En 's/^location:.+\/tag\/v(.+)\r$/\1/p')
curl -fsSLo kubectl-argo-rollouts "$REL/download/v${VER}/kubectl-argo-rollouts-linux-$ARCH"
chmod +x kubectl-argo-rollouts
kubectl argo rollouts version --short

# install kind: https://kind.sigs.k8s.io/docs/user/quick-start#installation
cd /usr/local/bin
REL="https://github.com/kubernetes-sigs/kind/releases"
VER=$(curl -Is "$REL/latest" | sed -En 's/^location:.+\/tag\/v(.+)\r$/\1/p')
curl -fsSLo kind "$REL/download/v${VER}/kind-linux-$ARCH"
chmod +x kind
kind --version

# install vCluster: https://www.vcluster.com/install
cd /usr/local/bin
REL="https://github.com/loft-sh/vcluster/releases"
VER=$(curl -Is "$REL/latest" | sed -En 's/^location:.+\/tag\/v(.+)\r$/\1/p')
curl -fsSLo vcluster "$REL/download/v${VER}/vcluster-linux-$ARCH"
chmod +x vcluster
vcluster version
