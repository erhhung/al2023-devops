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

# install Kustomize: https://kubectl.docs.kubernetes.io/installation/kustomize/binaries
REL="https://github.com/kubernetes-sigs/kustomize/releases/latest"
VER=$(curl -Is $REL | sed -En 's/^location:.+\/tag\/kustomize\/(.+)\r$/\1/p')
curl -fsSL "$REL/download/kustomize_${VER}_linux_${ARCH}.tar.gz" | \
  tar -xz -C /usr/local/bin --no-same-owner kustomize

# create our own wrapper script that sanitizes
# YAML files in and under the `kustomize build`
# directory (this is mainly to fix Kustomize's
# strict YAML parsing that chokes on duplicate
# keys, like labels, that Helm charts generate)
SCRIPT="/usr/local/bin/kustomize.sh"
cat <<'EOF' > $SCRIPT
#!/usr/bin/env bash
set -eo pipefail

sanitize() (
  while read file; do
    # this yq command does the following:
    # dedup keys with last-occurrence-wins
    # keep order of keys' first occurrence
    # preserve all docs with --- delimiter
    # preserve comments & trim whitespace

    # https://mikefarah.gitbook.io/yq/usage/tips-and-tricks#logic-without-if-elif-else
    # https://mikefarah.gitbook.io/yq/operators/multiply-merge#objects-and-arrays-merging

    yq -i --header-preprocess=false '{} as $temp
      | with(select(kind == "map"); $temp.init = {})
      | with(select(kind == "seq"); $temp.init = [])
      | . as $item ireduce ($temp.init; . *d $item)
      | "---\n\(to_yaml | trim)"' "$file"
  done < <(
    find "$1" \( -name '*.yaml' -o -name '*.yml' \)
  )
)
for arg in "$@"; do
  case "$arg" in
    build) build=1
           ;;
       -h|--help)
            help=1
           ;;
       -*) ;;
        *) [ ! "$build_dir" ] && [ "$build" ] \
           && [ -d "$arg" ] && build_dir="$arg"
           ;;
  esac
done

# sanitize only if actually building
[ "$build" ] && [ ! "$help" ] && \
  sanitize "${build_dir:-.}"

exec kustomize "$@"
EOF
chmod +x $SCRIPT

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
helm plugin install https://github.com/aslafy-z/helm-git
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

# install vals: https://github.com/helmfile/vals#installation
REL="https://github.com/helmfile/vals/releases/latest"
VER=$(curl -Is $REL | sed -En 's/^location:.+\/tag\/v(.+)\r$/\1/p')
curl -fsSL "$REL/download/vals_${VER}_linux_${ARCH}.tar.gz" | \
  tar -xz -C /usr/local/bin --no-same-owner vals
vals --version

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
