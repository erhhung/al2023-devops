# =========================================================
FROM public.ecr.aws/amazonlinux/amazonlinux:2023 AS builder
# =========================================================

# install common build tools
RUN <<'EOT'
set -e
echo "::group::Install common build tools"
( set -uxo pipefail

  dnf update
  dnf group install -y "Development Tools"
)
echo "::endgroup::"
EOT

# build Python 3.13: https://www.build-python-from-source.com/
RUN <<'EOT'
set -e
echo "::group::Build Python 3.13"
( set -uxo pipefail

  cd /tmp
  dnf install -y  openssl-devel bzip2-devel xz-devel libffi-devel \
    libuuid-devel gdbm-devel readline-devel tk-devel sqlite-devel
  VER="3.13"
  FTP="https://www.python.org/ftp/python"
  # determine the latest patch version
  ver=$(curl -s $FTP/ | sed -En 's/^.+href="('${VER/./\\.}'\..+)\/".+$/\1/p' | sort -Vr | head -1)
  curl -fsL $FTP/$ver/Python-$ver.tgz | tar -xz
  cd Python*
  # https://docs.python.org/3/using/configure.html
  ./configure -q \
    --prefix=/usr/local \
    --enable-optimizations \
    --with-lto=full \
    --with-computed-gotos
  make -sj$(nproc)
  # installs into (empty) dirs under /usr/local: /bin, /lib, /share/man/man1
  make altinstall
  alternatives --install /usr/local/bin/python3 python3 /usr/local/bin/python$VER 1
  alternatives --install /usr/local/bin/python  python  /usr/local/bin/python3    1
  alternatives --list
  hash -r
  python3 -VV
  python3 -m pip install -U --no-cache-dir --root-user-action=ignore pip
  # must copy all new symlinks in /etc/alternatives into the final image
  alternatives --install /usr/local/bin/pip3 pip3 /usr/local/bin/pip$VER 1
  alternatives --install /usr/local/bin/pip  pip  /usr/local/bin/pip3    1
  alternatives --list
  hash -r
  pip3 -V
)
echo "::endgroup::"
EOT

# build moreutils: https://joeyh.name/code/moreutils/
RUN <<'EOT'
set -e
echo "::group::Build moreutils"
( set -uxo pipefail

  cd /tmp
  dnf install -y libxslt docbook-xsl
  git clone -q git://git.joeyh.name/moreutils
  cd moreutils
  DOCBOOKXSL=/usr/share/sgml/docbook/xsl-stylesheets make -sj$(nproc)
  # installs into (empty) dirs under /usr/local: /bin, /share/man/man1
  PREFIX=/usr/local make install 2> /dev/null
  # "chronic" requires perl-IPC-Run
  # "ts" requires perl-Time-HiRes
  sponge -h
)
echo "::endgroup::"
EOT

# build GNU parallel: https://www.gnu.org/software/parallel/
RUN <<'EOT'
set -e
echo "::group::Build GNU parallel"
( set -uxo pipefail

  cd /tmp
  FTP="https://ftp.gnu.org/gnu/parallel"
  curl -fsL $FTP/parallel-latest.tar.bz2 | tar -xj
  cd parallel*
  ./configure --prefix=/usr/local -q
  make -sj$(nproc)
  # installs into (empty) dirs under /usr/local: /bin, /share/man/man1,
  #   /share/bash-completion/completions, /share/zsh/site-functions
  make install
  echo "will cite" | parallel --citation &> /dev/null
  parallel --version
)
echo "::endgroup::"
EOT

# build tini: https://github.com/krallin/tini
RUN <<'EOT'
set -e
echo "::group::Build tini"
( set -uxo pipefail

  cd /tmp
  dnf install -y cmake glibc-static
  git clone -q https://github.com/krallin/tini
  cd tini
  export CFLAGS="-DPR_SET_CHILD_SUBREAPER=36 -DPR_GET_CHILD_SUBREAPER=37"
  cmake .
  make -sj$(nproc)
  # installs into /usr/local/bin
  PREFIX=/usr/local make install
  tini --version
)
echo "::endgroup::"
EOT

# build jo: https://github.com/jpmens/jo
RUN <<'EOT'
set -e
echo "::group::Build jo"
( set -uxo pipefail

  cd /tmp
  git clone -q https://github.com/jpmens/jo
  cd jo
  autoreconf -i
  ./configure --prefix=/usr/local -q
  make -j$(nproc) check
  # installs into (empty) dirs under /usr/local: /bin, /share/man/man1,
  #   /etc/bash_completion.d, /share/zsh/site-functions
  make install
  jo -v
)
echo "::endgroup::"
EOT

# copy Docker binaries, including BuildX and Compose
COPY --from=public.ecr.aws/docker/library/docker:dind /usr/local/bin/docker                  /usr/local/bin/
COPY --from=public.ecr.aws/docker/library/docker:dind /usr/local/libexec/docker/cli-plugins/ /usr/local/bin/

# install Docker BuildX and Compose as user plugins
RUN <<'EOT'
set -e
echo "::group::Install Docker BuildX and Compose"
( set -uxo pipefail

  PLUGIN_DIR="/root/.docker/cli-plugins"
  mkdir -p $PLUGIN_DIR
  alternatives --install $PLUGIN_DIR/docker-buildx  docker-buildx  /usr/local/bin/docker-buildx  1
  alternatives --install $PLUGIN_DIR/docker-compose docker-compose /usr/local/bin/docker-compose 1
  docker buildx  install
  docker buildx  version
  docker compose version
)
echo "::endgroup::"
EOT

# ==========================
FROM scratch AS consolidator
# ==========================

# copy directories installed to in the builder stage
COPY --from=builder /usr/local/bin/         /usr/local/bin/
COPY --from=builder /usr/local/lib/         /usr/local/lib/
COPY --from=builder /usr/local/include/     /usr/local/include/
COPY --from=builder /usr/local/share/       /usr/local/share/
COPY --from=builder /usr/local/etc/         /usr/local/etc/
COPY --from=builder /etc/alternatives/      /etc/alternatives/
COPY --from=builder /var/lib/alternatives/  /var/lib/alternatives/
COPY --from=builder /root/.docker/          /root/.docker/

# configure locale; others will be purged from /usr/{lib,share}/locale
COPY <<'EOF' /etc/locale.conf
LANGUAGE=en_US
LANG=en_US.UTF-8
LC_CTYPE="en_US.UTF-8"
LC_NUMERIC="en_US.UTF-8"
LC_TIME="en_US.UTF-8"
LC_COLLATE="en_US.UTF-8"
LC_MONETARY="en_US.UTF-8"
LC_MESSAGES="en_US.UTF-8"
LC_PAPER="en_US.UTF-8"
LC_NAME="en_US.UTF-8"
LC_ADDRESS="en_US.UTF-8"
LC_TELEPHONE="en_US.UTF-8"
LC_MEASUREMENT="en_US.UTF-8"
LC_IDENTIFICATION="en_US.UTF-8"
LC_ALL=
EOF

# copy various dotfiles
COPY ./config/ /root/
# copy various scripts
COPY ./scripts/ /tmp/

# =======================================================
FROM public.ecr.aws/amazonlinux/amazonlinux:2023 AS final
# =======================================================

#LABEL name="al2023-devops"
#LABEL description="Amazon Linux 2023 with Python 3.13, Go 1.23, Node.js 22, AWS CLI, Mountpoint for S3, CDK, CDK8s, Docker, Kubectl, Krew, Helm, Argo CD, and utilities like jq, jo, yq, jsonnet, and Just"
#LABEL maintainer="erhhung@gmail.com"

ENV TERM="xterm-256color"
ENV LANGUAGE="en_US"
ENV PYGMENTSTYLE="base16-materia"
ENV CDK8S_CHECK_UPGRADE="false"
ENV JSII_SILENCE_WARNING_DEPRECATED_NODE_VERSION="1"
ENV PATH="/usr/local/poetry/bin:$PATH:/root/.krew/bin"

# Copy all consolidated files
COPY --from=consolidator / /

WORKDIR /root

RUN <<'EOT'
set -e
echo "::group::Install Linux utilities"
( set -uxo pipefail

  # use the appropriate binaries for this multi-arch Docker image
  ARCH=$(uname -m | sed -e 's/aarch64/arm64/' -e 's/x86_64/amd64/')

  # save the exact Amazon Linux release version
  rpm -q system-release | sed -En 's/^.+-(2023.+)-.+$/\1/p' > /etc/dnf/vars/releasever
  dnf check-update

  # install common utilities (procps provides "free" command)
  # perl-IPC-Run and perl-Time-HiRes are required by moreutils
  dnf install -y git wget tar xz bzip2 gzip unzip man bash-completion \
    which findutils pwgen gettext procps sshpass openssl nmap tmux vim \
    bc glibc-locale-source glibc-langpack-en perl-IPC-Run perl-Time-HiRes
  dnf clean all
  rm -rf /var/log/* /var/cache/dnf
  alternatives --install /usr/local/bin/vi vi /usr/bin/vim 1
  alternatives --list

  # install tmux plugins: https://github.com/tmux-plugins/tpm#installation
  TMUX_PLUGIN_MANAGER_PATH="/root/.tmux/plugins/tpm"
  git clone -q https://github.com/tmux-plugins/tpm $TMUX_PLUGIN_MANAGER_PATH
  # install requires previously copied .tmux.conf
  $TMUX_PLUGIN_MANAGER_PATH/bin/install_plugins

  # purge unused locales
  # $LANGUAGE is set by the Dockerfile ENV command
  localedef -i $LANGUAGE -f UTF-8 $LANGUAGE.UTF-8
  find /usr/{lib,share}/locale/* -maxdepth 0 -type d -not -iname "$LANGUAGE*" -exec rm -rf {} \;

  # install just: https://github.com/casey/just#pre-built-binaries
  cd /tmp
  REL="https://github.com/casey/just/releases/latest"
  VER=$(curl -Is $REL | sed -En 's/^location:.+\/tag\/(.+)\r$/\1/p')
  URL="$REL/download/just-$VER-$(uname -m)-unknown-linux-musl.tar.gz"
  curl -fsSL $URL | tar -xz --no-same-owner just* completions/*.bash
  mv just     /usr/local/bin
  mv */*.bash /usr/local/etc/bash_completion.d
  mv just.1   /usr/local/share/man/man1
  rm -rf completions
  just --version

  install_bin() {
    cd /usr/local/bin
    local bin=$1 src=$2
    curl -fsSLo $bin $src
    chmod +x $bin
    $bin --version
  }

  # install sops: https://github.com/getsops/sops
  REL="https://github.com/getsops/sops/releases/latest"
  VER=$(curl -Is $REL | sed -En 's/^location:.+\/tag\/(.+)\r$/\1/p')
  install_bin sops "$REL/download/sops-$VER.linux.$ARCH"

  # install jq: https://stedolan.github.io/jq
  install_bin jq "https://github.com/stedolan/jq/releases/latest/download/jq-linux-$ARCH"
  # install yq: https://github.com/mikefarah/yq
  install_bin yq "https://github.com/mikefarah/yq/releases/latest/download/yq_linux_$ARCH"

  EPEL="https://dl.fedoraproject.org/pub/epel"
  rpm --import $EPEL/RPM-GPG-KEY-EPEL-9

  install_rpms() {
    local pkg url
    for pkg in "$@"; do
      url="$EPEL/9/Everything/$(uname -m)/Packages/${pkg::1}/"
      url+=$(curl -sL $url | sed -En 's/^.+href="('${pkg}'-[0-9.]+[^"]+).+$/\1/p')
      rpm -i $url
    done
  }

  # install jsonnet: https://jsonnet.org/
  install_rpms c4core rapidyaml jsonnet-libs jsonnet
  jsonnet --version
)
echo "::endgroup::"
EOT

# install Python tools
RUN <<'EOT'
set -e
echo "::group::Install Python tools"
( set -uxo pipefail

  # install Poetry: https://python-poetry.org/docs/#installing-with-the-official-installer
  curl -fsSL https://install.python-poetry.org | \
    POETRY_HOME="/usr/local/poetry" python3 -
  # /usr/local/poetry/bin is already in $PATH via Dockerfile ENV command
  poetry -V

  # install pipx, Pygments, ansitable, and Ansible
  pip3 install --no-cache-dir --root-user-action=ignore \
    pipx pygments colored ansitable ansible \
    jsonpatch kubernetes kubernetes-validate
  rm -rf /root/.cache
  pipx --version
  pygmentize -V
)
echo "::endgroup::"
EOT

# install Golang 1.23
RUN <<'EOT'
set -e
echo "::group::Install Golang 1.23"
( set -uxo pipefail

  dnf install -y golang
  dnf clean all
  rm -rf /var/log/* /var/cache/dnf
  go version

  # purge unused locales
  # $LANGUAGE is set by the Dockerfile ENV command
  find /usr/{lib,share}/locale/* -maxdepth 0 -type d -not -iname "$LANGUAGE*" -exec rm -rf {} \;
)
echo "::endgroup::"
EOT

# install Node.js 22
RUN <<'EOT'
set -e
echo "::group::Install Node.js 22"
( set -uxo pipefail

  curl -fsSL https://rpm.nodesource.com/setup_22.x | bash -
  dnf install -y nodejs
  dnf clean all
  rm -rf /var/log/* /var/cache/dnf
  npm install -g npm
  node --version
  npm  --version

  HOME=/root
  # https://docs.npmjs.com/cli/v9/using-npm/config
  npm config set update-notifier false
  npm config set loglevel warn
  npm config set fund false
  rm -rf /root/.npm
)
echo "::endgroup::"
EOT

# install AWS tools
RUN <<'EOT'
set -e
echo "::group::Install AWS tools"
( set -uxo pipefail

  # install AWS CLI v2: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html
  cd /tmp
  curl -fsSLo awscliv2.zip https://awscli.amazonaws.com/awscli-exe-linux-$(uname -m).zip
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
  curl -fsSL $REL/$ARCH/mount-s3.tar.gz | \
    tar -xz -C /usr/local/bin --no-same-owner --strip 2 ./bin
  mount-s3 --version
)
echo "::endgroup::"
EOT

# install OCI image tools
RUN <<'EOT'
set -e
echo "::group::Install OCI image tools"
( set -uxo pipefail

  # use the appropriate binaries for this multi-arch Docker image
  ARCH=$(uname -m | sed -e 's/aarch64/arm64/' -e 's/x86_64/amd64/')

  # install Dive: https://github.com/wagoodman/dive#installation
  REL="https://github.com/wagoodman/dive/releases/latest"
  VER=$(curl -Is $REL | sed -En 's/^location:.+\/tag\/v(.+)\r$/\1/p')
  curl -fsSL $REL/download/dive_${VER}_linux_${ARCH}.tar.gz | \
    tar -xz -C /usr/local/bin --no-same-owner dive
  dive --version
  (
    # install MinToolkit: https://github.com/mintoolkit/mint#installation
    REL="https://github.com/mintoolkit/mint/releases/latest"
    # name must be *linux.* or *linux_arm64.*
    ARCH=${ARCH/%amd*/} ARCH=${ARCH/arm/_arm}
    curl -fsSL $REL/download/dist_linux${ARCH}.tar.gz | \
      tar -xz -C /usr/local/bin --no-same-owner --strip 1 dist_linux${ARCH}/mint*
    mint --version
  )
)
echo "::endgroup::"
EOT

# install Kubernetes tools
RUN <<'EOT'
set -e
echo "::group::Install Kubernetes tools"
( set -uxo pipefail

  # use the appropriate binaries for this multi-arch Docker image
  ARCH=$(uname -m | sed -e 's/aarch64/arm64/' -e 's/x86_64/amd64/')

  # install Kubectl: https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/
  cd /usr/local/bin
  REL="https://dl.k8s.io/release"
  VER=$(curl -sL $REL/stable.txt)
  curl -fsSLO $REL/$VER/bin/linux/$ARCH/kubectl
  chmod +x kubectl
  kubectl version --client

  # install Kubeconform: https://github.com/yannh/kubeconform#installation
  REL="https://github.com/yannh/kubeconform/releases/latest"
  curl -fsSL $REL/download/kubeconform-linux-${ARCH}.tar.gz | \
    tar -xz -C /usr/local/bin --no-same-owner kubeconform
  ln -s /usr/local/bin/kubeconform /usr/local/bin/kubectl-conform
  kubectl conform -v

  # install Krew: https://krew.sigs.k8s.io/docs/user-guide/setup/install/
  cd /tmp
  REL="https://github.com/kubernetes-sigs/krew/releases/latest"
  KREW=krew-linux_${ARCH}
  curl -fsSL $REL/download/$KREW.tar.gz | tar -xz ./$KREW
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
    curl -fsSL $REL/download/kube-score_${VER}_linux_${ARCH}.tar.gz | \
      tar -C /root/.krew/store/score/* -xz
  fi
  kubectl score version

  # install kind: https://kind.sigs.k8s.io/docs/user/quick-start#installation
  cd /usr/local/bin
  REL="https://github.com/kubernetes-sigs/kind/releases/latest"
  curl -fsSLo kind $REL/download/kind-linux-${ARCH}
  chmod +x kind
  kind --version

  # install vCluster: https://www.vcluster.com/install
  cd /usr/local/bin
  REL="https://github.com/loft-sh/vcluster/releases/latest"
  curl -fsSLo vcluster $REL/download/vcluster-linux-${ARCH}
  chmod +x vcluster
  vcluster version

  # install Helm: https://helm.sh/docs/intro/install/
  REL="https://github.com/helm/helm/releases/latest"
  VER=$(curl -Is $REL | sed -En 's/^location:.+\/tag\/(.+)\r$/\1/p')
  curl -fsSL https://get.helm.sh/helm-$VER-linux-${ARCH}.tar.gz | \
    tar -xz -C /usr/local/bin --no-same-owner --strip 1 linux-${ARCH}/helm
  helm version

  # install helm-docs: https://github.com/norwoodj/helm-docs#installation
  REL="https://github.com/norwoodj/helm-docs/releases/latest"
  VER=$(curl -Is $REL | sed -En 's/^location:.+\/tag\/v(.+)\r$/\1/p')
  arch=$(uname -m | sed -e 's/aarch64/arm64/') # must be x86_64 or arm64
  curl -fsSL $REL/download/helm-docs_${VER}_Linux_${arch}.tar.gz | \
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
    curl -fsSL $REL/download/helm-ssm-linux${ARCH}.tgz | tar -xz
    VER=$(curl -Is $REL | sed -En 's/^location:.+\/tag\/(.+)\r$/\1/p')
    sed -i "s/\"dev\"/\"$VER\"/" plugin.yaml
    helm ssm --help
  )
  helm plugin list
  rm -rf /root/.cache

  # install Helmfile: https://github.com/helmfile/helmfile#installation
  REL="https://github.com/helmfile/helmfile/releases/latest"
  VER=$(curl -Is $REL | sed -En 's/^location:.+\/tag\/v(.+)\r$/\1/p')
  curl -fsSL $REL/download/helmfile_${VER}_linux_${ARCH}.tar.gz | \
    tar -xz -C /usr/local/bin --no-same-owner helmfile
  helmfile --version

  # install Argo CD: https://argo-cd.readthedocs.io/en/stable/cli_installation/
  cd /usr/local/bin
  REL="https://github.com/argoproj/argo-cd/releases/latest"
  curl -fsSLo argocd $REL/download/argocd-linux-${ARCH}
  chmod +x argocd
  argocd version --client --short

  # install Argo Rollouts: https://argoproj.github.io/argo-rollouts/installation/
  cd /usr/local/bin
  REL="https://github.com/argoproj/argo-rollouts/releases/latest"
  curl -fsSLo kubectl-argo-rollouts $REL/download/kubectl-argo-rollouts-linux-${ARCH}
  chmod +x kubectl-argo-rollouts
  kubectl argo rollouts version --short
)
echo "::endgroup::"
EOT

# FINAL step of Dockerfile: run custom "versions.sh" script
# (copied in prior stage) to generate "/root/.versions.json":
# manifest of all installed tools and their current versions
RUN <<'EOT'
set -e
echo "::group::Generate .versions.json"
( set -uxo pipefail

  /tmp/versions.sh
  dnf clean all
  rm -rf /tmp/* /var/log/* /var/cache/dnf
)
echo "::endgroup::"
EOT

CMD ["bash", "--login"]
