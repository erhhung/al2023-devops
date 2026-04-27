#!/usr/bin/env bash

# this script is meant to be executed in the al2023-devops
# container to extract the versions of all tools installed

# shellcheck disable=SC2155 # Declare and assign separately
# shellcheck disable=SC2086 # Double quote prevent globbing
# shellcheck disable=SC2016 # Expr won't expand in '' quotes
# shellcheck disable=SC2207 # Prefer mapfile to split output
# shellcheck disable=SC2006 # Prefer $(...) over legacy `...`

echo "::group::Generate .versions.json"

TMP=()
on_exit() {
  rm -rf "${TMP[@]}"
  echo "::endgroup::"
}
trap on_exit EXIT
set -euxo pipefail

OUT="/root/.versions.json"
# create empty object
jo < /dev/null > $OUT

# <component> <version>
setver() {
  local comp=$1 ver="$2"
  if [[ "$ver" == '$('*')' ]]; then
    # run command to get version number; assumes
    # component isn't installed if command fails
    ver="${ver/#\$(/\$(set +eu; }"
    eval "ver=${ver/%)/; exit 0)}"
  fi
  if [ "$ver" ]; then
    echo >&2 "$comp: $ver"
    jo -- -s "$comp"="$ver" | jq -sSM '.[0]*.[1]' $OUT - | sponge $OUT
  else
    echo >&2 "$comp: NOT INSTALLED"
    return 0
  fi
}

# <package>
dnfver() {
  local v=(`dnf list installed "$1" | tail -1`)
  echo "${v[1]%.amzn*}"
}

# <repository>
gclone() {
  local dir=/tmp/$(basename $1)
  TMP+=("$dir");  rm -rf "$dir"
  git clone --bare -q $1 "$dir" && cd "$dir"
}

# <repository>
grelease() {
  curl -Is "$1/releases/latest" | sed -En 's/^location:.+\/tag\/(.+)\r$/\1/p'
}

setver age '$(v=`age --version`; echo ${v#v})'
setver ansible '$(v=(`ansible --version | head -1`); echo ${v[-1]%\]})'
setver argocd '$(v=(`argocd version --client --short`); v=${v[-1]#v}; echo ${v%+*})'
setver aws '$(v=(`aws --version`); echo ${v[0]#*/})'
setver awx '$(awx --version)'
setver bash ${BASH_VERSION/%\(*/}
setver bc '$(v=(`bc --version | head -1`); echo ${v[-1]})'
setver buildah '$(v=(`buildah --version`); echo ${v[2]})'
setver bzip '$(v=(`bzip2 --version < /dev/null 2>&1 | head -1`); echo ${v[-2]%,})'
setver cdk '$(v=(`cdk version | head -1`); echo $v)'
setver cdk8s '$(cdk8s --version)'
setver crun '$(v=(`crun --version`); echo ${v[2]})'
setver curl '$(v=(`curl --version`); echo ${v[1]})'
setver dive '$(v=(`dive --version`); echo ${v[-1]})'
setver docker '$(docker version --format json 2> /dev/null | jq -r .Client.Version)'
setver docker-buildx '$(v=(`docker buildx version`); echo ${v[1]#v})'
setver docker-compose '$(v=(`docker compose version`); echo ${v[-1]#v})'
setver envsubst '$(v=(`envsubst --version | head -1`); echo ${v[-1]})'
setver find '$(v=(`find --version | head -1`); echo ${v[-1]})'
setver free '$(v=(`free --version`); echo ${v[-1]})'
setver git '$(v=(`git version`); echo ${v[2]})'
setver go '$(v=(`go version`); echo ${v[2]#go})'
setver gomplate '$(v=(`gomplate --version`); echo ${v[-1]})'
setver gzip '$(v=(`gzip --version | head -1`); echo ${v[-1]})'
setver helm '$(v=`helm version --short`; v=${v#v}; echo ${v%+*})'
setver helm-diff '$(helm diff version)'
setver helm-docs '$(v=(`helm-docs --version`); echo ${v[-1]})'
setver helm-git '$(v=(`helm plugin list | grep git`); echo ${v[1]})'
setver helm-secrets '$(helm secrets --version | head -1)'
setver helm-ssm '$(v=(`helm plugin list | grep ssm`); echo ${v[1]})'
setver helmfile '$(helmfile version -o short 2> /dev/null)'
setver java '$(v=(`java --version | head -1`); echo ${v[1]})'
setver jo '$(jo -V | jq -r .version)'
setver jq '$(v=`jq --version`; echo ${v#*-})'
setver jsonnet '$(v=(`jsonnet --version`); echo ${v[-1]#v})'
setver just '$(v=(`just --version`); echo ${v[1]})'
setver kind '$(v=(`kind --version`); echo ${v[-1]})'
setver krew '$(v=(`kubectl krew version | grep GitTag`); echo ${v[1]#v})'
setver kube-score '$(v=(`kubectl score version`); echo ${v[2]%,})'
setver kubeconform '$(v=`kubectl conform -v`; echo ${v#v})'
setver kubectl '$(v=(`kubectl version --client | head -1`); echo ${v[2]#v})'
setver kubectl-argo-rollouts '$(v=(`kubectl argo rollouts version --short`); v=${v[-1]#v}; echo ${v%+*})'
setver kubectl-grep '$(v=`kubectl grep version --short`; echo ${v#v})'
setver kustomize '$(v=`kustomize version`; echo ${v#v})'
setver maven '$(v=(`mvn --version | head -1`); echo ${v[2]})'
setver md5sum '$(v=(`md5sum --version | head -1`); echo ${v[-1]})'
setver mint '$(v=`mint --version`; v=(${v//|/ }); echo ${v[4]%%-*})'
gclone git://git.joeyh.name/moreutils
setver moreutils '$(git describe --abbrev=0)'
setver mount-s3 '$(v=(`mount-s3 --version`); echo ${v[-1]})'
setver netavark '$(v=(`/usr/local/libexec/podman/netavark --version`); echo ${v[-1]})'
setver nmap '$(v=(`nmap --version | head -1`); echo ${v[2]})'
setver node '$(v=`node --version`; echo ${v#v})'
setver npm '$(npm --version)'
setver openssl '$(v=(`openssl version`); echo ${v[1]})'
setver oras '$(v=(`oras version | head -1`); echo ${v[1]%+*})'
setver parallel '$(v=(`parallel --version | head -1`); echo ${v[2]})'
setver pip '$(v=(`pip --version`); echo ${v[1]})'
setver pipx '$(pipx --version)'
setver pnpm '$(pnpm --version)'
setver poetry '$(v=(`poetry --version`); echo ${v[2]%)})'
setver pwgen '$(dnfver pwgen)'
setver pygments '$(v=(`pygmentize -V`); echo ${v[2]%,})'
setver python '$(v=(`python --version`); echo ${v[-1]})'
setver q '$(v=(`q --version`); echo ${v[2]})'
setver runc '$(v=(`runc --version`); echo ${v[2]})'
setver skopeo '$(v=(`skopeo --version`); echo ${v[2]})'
setver sops '$(v=(`sops --version | head -1`); echo ${v[1]})'
setver sshpass '$(v=(`sshpass -V | head -1`); echo ${v[-1]})'
setver tar '$(v=(`tar --version | head -1`); echo ${v[-1]})'
setver terraform '$(v=(`terraform version | head -1`); echo ${v[-1]#v})'
setver tini '$(v=(`tini --version`); echo ${v[2]})'
setver tmux '$(v=(`tmux -V`); echo ${v[-1]})'
setver unzip '$(v=(`unzip | head -1`); echo ${v[1]})'
setver uv '$(v=(`uv --version`); echo ${v[1]})'
setver vals '$(v=(`vals version`); echo ${v[1]})'
setver vcluster '$(v=(`vcluster version`); echo ${v[-1]})'
setver vim '$(v=(`vim --version | head -1`); echo ${v[4]})'
setver wait4x '$(v=(`wait4x version | grep Version`); echo ${v[1]#v})'
setver wget '$(v=(`wget --version | head -1`); echo ${v[2]})'
setver which '$(v=(`which --version | head -1`); v=${v[2]#v}; echo ${v%,})'
setver xz '$(v=(`xz --version | head -1`); echo ${v[-1]})'
setver yq '$(v=(`yq --version`); echo ${v[3]#v})'
