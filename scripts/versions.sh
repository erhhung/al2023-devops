#!/usr/bin/env bash
set -euo pipefail

# this script is meant to be executed in the al2023-devops
# container to extract the versions of all tools installed

TMP=()
trap 'rm -rf "${TMP[@]}"' EXIT

OUT=/root/.versions.json
# create empty object
jo < /dev/null > $OUT

# <component> <version>
setver() {
  echo >&2 $1: $2
  jo -- -s $1="$2" | jq -sSM '.[0]*.[1]' $OUT - | sponge $OUT
}

# <package>
dnfver() {
  local v=(`dnf list installed $1 | tail -1`)
  echo ${v[1]%.amzn*}
}

# <repository>
gclone() {
  local dir=/tmp/$(basename $1)
  TMP+=($dir); rm -rf $dir
  git clone --bare -q $1 $dir && cd $dir
}

# <repository>
grelease() {
  curl -Is $1/releases/latest | sed -En 's/^location:.+\/tag\/(.+)\r$/\1/p'
}

setver argocd $(v=(`argocd version --client --short`); v=${v[-1]#v}; echo ${v%+*})
setver aws $(v=(`aws --version`); echo ${v[0]#*/})
setver bash ${BASH_VERSION/%\(*/}
setver bc $(v=(`bc --version | head -1`); echo ${v[-1]})
setver bzip $(v=(`bzip2 --version < /dev/null 2>&1 | head -1`); echo ${v[-2]%,})
setver cdk $(v=(`cdk version | head -1`); echo $v)
setver cdk8s $(cdk8s --version)
setver dive $(v=(`dive --version`); echo ${v[-1]})
setver docker $(docker version --format json 2> /dev/null | jq -r .Client.Version)
setver docker-buildx $(v=(`docker buildx version`); echo ${v[1]#v})
setver docker-compose $(v=(`docker compose version`); echo ${v[-1]#v})
setver envsubst $(v=(`envsubst --version | head -1`); echo ${v[-1]})
setver find $(v=(`find --version | head -1`); echo ${v[-1]})
setver free $(v=(`free --version`); echo ${v[-1]})
setver git $(v=(`git version`); echo ${v[2]})
setver go $(v=(`go version`); echo ${v[2]#go})
setver gzip $(v=(`gzip --version | head -1`); echo ${v[-1]})
setver helm $(v=`helm version --short`; v=${v#v}; echo ${v%+*})
setver helm-diff $(helm diff version)
setver helm-ssm $(v=(`helm plugin list | grep ssm`); echo ${v[1]})
setver helmfile $(helmfile version -o short)
setver jo $(jo -V | jq -r .version)
setver jq $(v=`jq --version`; echo ${v#*-})
setver jsonnet $(v=(`jsonnet --version`); echo ${v[-1]#v})
setver just $(v=(`just --version`); echo ${v[1]})
setver kind $(v=(`kind --version`); echo ${v[-1]})
setver krew $(v=(`kubectl krew version | grep GitTag`); echo ${v[1]#v})
setver kube-score $(v=(`kubectl score version`); echo ${v[2]%,})
setver kubeconform $(v=`kubectl conform -v`; echo ${v#v})
setver kubectl $(v=(`kubectl version --client | head -1`); echo ${v[2]#v})
setver kubectl-argo-rollouts $(v=(`kubectl argo rollouts version --short`); v=${v[-1]#v}; echo ${v%+*})
setver kubectl-grep $(v=`kubectl grep version --short`; echo ${v#v})
setver md5sum $(v=(`md5sum --version | head -1`); echo ${v[-1]})
setver mint $(v=`mint --version`; v=(${v//|/ }); echo ${v[-3]})
gclone git://git.joeyh.name/moreutils
setver moreutils $(git describe --abbrev=0)
setver mount-s3 $(v=(`mount-s3 --version`); echo ${v[-1]})
setver nmap $(v=(`nmap --version | head -1`); echo ${v[2]})
setver node $(v=`node --version`; echo ${v#v})
setver npm $(npm --version)
setver openssl $(v=(`openssl version`); echo ${v[1]})
setver parallel $(v=(`parallel --version | head -1`); echo ${v[2]})
setver pip $(v=(`pip --version`); echo ${v[1]})
setver pipx $(pipx --version)
setver poetry $(v=(`poetry --version`); echo ${v[2]%)})
setver pwgen $(dnfver pwgen)
setver pygments $(v=(`pygmentize -V`); echo ${v[2]%,})
setver python $(v=(`python --version`); echo ${v[-1]})
setver sops $(v=(`sops --version | head -1`); echo ${v[1]})
setver tar $(v=(`tar --version | head -1`); echo ${v[-1]})
setver tini $(v=(`tini --version`); echo ${v[2]})
setver tmux $(v=(`tmux -V`); echo ${v[-1]})
setver unzip $(v=(`unzip | head -1`); echo ${v[1]})
setver vcluster $(v=(`vcluster version`); echo ${v[-1]})
setver vim $(v=(`vim --version | head -1`); echo ${v[4]})
setver wget $(v=(`wget --version | head -1`); echo ${v[2]})
setver which $(v=(`which --version | head -1`); v=${v[2]#v}; echo ${v%,})
setver xz $(v=(`xz --version | head -1`); echo ${v[-1]})
setver yq $(v=(`yq --version`); echo ${v[3]#v})
