FROM public.ecr.aws/amazonlinux/amazonlinux:2023 AS builder

# install common build tools
RUN <<'EOT'
set -e
echo "::group::Install common build tools"
( set -euxo pipefail

  dnf update
  dnf group install -y "Development Tools"
  dnf install -y which
)
echo "::endgroup::"
EOT

# build Python 3.12: https://www.build-python-from-source.com/
RUN <<'EOT'
set -e
echo "::group::Build Python 3.12"
( set -euxo pipefail

  cd /tmp
  dnf install -y  openssl-devel bzip2-devel xz-devel libffi-devel \
    libuuid-devel gdbm-devel readline-devel tk-devel sqlite-devel
  VER="3.12"
  FTP="https://www.python.org/ftp/python"
  # determine the latest patch version
  ver=$(curl -s $FTP/ | sed -En 's/^.+href="('${VER/./\\.}'\..+)\/".+$/\1/p' | sort -Vr | head -1)
  curl -sL $FTP/$ver/Python-$ver.tgz | tar -xz
  cd Python*
  # https://docs.python.org/3/using/configure.html
  ./configure -q \
    --prefix=/usr/local \
    --enable-optimizations \
    --with-lto=full \
    --with-computed-gotos
  make -sj$(nproc)
  # installs into (empty) dirs under /usr/local: /bin, /lib, /share/man/man1
  make -s altinstall
  alternatives --install /usr/local/bin/python3 python3 /usr/local/bin/python$VER 1
  alternatives --install /usr/local/bin/python  python  /usr/local/bin/python3    1
  # must copy new symlinks in /etc/alternatives into the final image
  alternatives --list
  hash -r
  python3 -VV
  python3 -m pip install -U --no-cache-dir --root-user-action=ignore pip
  which pip$VER pip3 pip || true
  pip3 -V
)
echo "::endgroup::"
EOT

# build moreutils: https://joeyh.name/code/moreutils/
RUN <<'EOT'
set -e
echo "::group::Build moreutils"
( set -euxo pipefail

  cd /tmp
  dnf install -y libxslt docbook-xsl
  git clone -s git://git.joeyh.name/moreutils
  cd moreutils
  # fix error: cannot parse /usr/share/xml/docbook/stylesheet/docbook-xsl/manpages/docbook.xsl
  sed -i '/ifneq/,/endif/cDOCBOOKXSL?=\/usr\/share\/sgml\/docbook/xsl-stylesheets' Makefile
  make -sj$(nproc)
  # installs into (empty) dirs under /usr/local: /bin, /share/man/man1
  PREFIX=/usr/local make install
  sponge -h
)
echo "::endgroup::"
EOT

# build GNU parallel: https://www.gnu.org/software/parallel/
RUN <<'EOT'
set -e
echo "::group::Build GNU parallel"
( set -euxo pipefail

  cd /tmp
  FTP="https://ftp.gnu.org/gnu/parallel"
  curl -sL $FTP/parallel-latest.tar.bz2 | tar -xj
  cd parallel*
  ./configure --enable-optimizations --prefix=/usr/local -q
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
( set -euxo pipefail

  cd /tmp
  dnf install -y cmake glibc-static
  git clone -s https://github.com/krallin/tini.git
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
( set -euxo pipefail

  cd /tmp
  git clone -s https://github.com/jpmens/jo.git
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

# ==============================================
FROM public.ecr.aws/amazonlinux/amazonlinux:2023
# ==============================================

#LABEL name="al2023-devops"
#LABEL description="Amazon Linux 2023 with Python 3.12, Go 1.22, Node.js 22, AWS CLI, Mountpoint for S3, CDK, CDK8s, Docker, Kubectl, Krew, Helm, and utilities like Just, jq, jo and yq"
#LABEL maintainer="erhhung@gmail.com"

ENV TERM="xterm-256color"
ENV LANGUAGE="en_US"
ENV PYGMENTSTYLE="base16-materia"
ENV CDK8S_CHECK_UPGRADE="false"
ENV JSII_SILENCE_WARNING_DEPRECATED_NODE_VERSION="1"
ENV PATH="/usr/local/poetry/bin:$PATH:/root/.krew/bin"

# copy directories installed to in the builder stage
COPY --from=builder /usr/local/bin/     /usr/local/bin/
COPY --from=builder /usr/local/lib/     /usr/local/lib/
COPY --from=builder /usr/local/include/ /usr/local/include/
COPY --from=builder /usr/local/share/   /usr/local/share/
COPY --from=builder /usr/local/etc/     /usr/local/etc/
COPY --from=builder /etc/alternatives/  /etc/alternatives/

# copy Docker binaries, including Compose and BuildX
COPY --from=public.ecr.aws/docker/library/docker:dind /usr/local/bin/docker                  /usr/local/bin/
COPY --from=public.ecr.aws/docker/library/docker:dind /usr/local/libexec/docker/cli-plugins/ /usr/local/bin/

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

# install Docker Compose and BuildX as user plugins
RUN <<'EOT'
set -e
echo "::group::Install Docker Compose and BuildX"
( set -euxo pipefail

  HOME=/root
  PLUGIN_DIR="$HOME/.docker/cli-plugins"
  mkdir -p $PLUGIN_DIR
  alternatives --install $PLUGIN_DIR/docker-compose docker-compose /usr/local/bin/docker-compose 1
  alternatives --install $PLUGIN_DIR/docker-buildx  docker-buildx  /usr/local/bin/docker-buildx  1
  docker compose version
  docker buildx  install
  docker buildx  version
)
echo "::endgroup::"
EOT

RUN <<'EOT'
set -e
echo "::group::Install common utilities"
( set -euxo pipefail

  # use the appropriate binaries for this multi-arch Docker image
  ARCH=$(uname -m | sed -e 's/aarch64/arm64/' -e 's/x86_64/amd64/')

  # save the exact Amazon Linux release version
  rpm -q system-release | sed -En 's/^.+-(2023.+)-.+$/\1/p' > /etc/dnf/vars/releasever
  dnf check-update

  # install common utilities (procps provides the "free" command)
  dnf install -y tar xz bzip2 gzip unzip wget git which findutils \
    bc man pwgen gettext procps openssl nmap bash-completion tmux \
    vim glibc-locale-source glibc-langpack-en
  dnf clean all
  rm -rf /var/log/* /var/cache/dnf
  alternatives --install /usr/local/bin/vi vi /usr/bin/vim 1
  alternatives --list

  # install tmux plugins: https://github.com/tmux-plugins/tpm#installation
  TMUX_PLUGIN_MANAGER_PATH="/root/.tmux/plugins/tpm"
  git clone https://github.com/tmux-plugins/tpm $TMUX_PLUGIN_MANAGER_PATH
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
  curl -sSL $URL | tar -xz --no-same-owner just* completions/*.bash
  mv just     /usr/local/bin
  mv */*.bash /usr/local/etc/bash_completion.d
  mv just.1   /usr/local/share/man/man1
  rmdir completions

  install_bin() {
    cd /usr/local/bin
    local bin=$1 src=$2
    curl -sSLo $bin $src
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
)
echo "::endgroup::"
EOT

# install Python tools
RUN <<'EOT'
set -e
echo "::group::Install Python tools"
( set -euxo pipefail

  # install Poetry: https://python-poetry.org/docs/#installing-with-the-official-installer
  curl -sSL https://install.python-poetry.org | \
    POETRY_HOME="/usr/local/poetry" python3 -
  # /usr/local/poetry/bin is already in $PATH via Dockerfile ENV command
  poetry -V

  # install pipx, Pygments and ansitable
  pip3 install --no-cache-dir --root-user-action=ignore pipx pygments colored ansitable
  pipx ensurepath --global && pipx --version
  rm -rf /root/.cache
  pygmentize -V
)
echo "::endgroup::"
EOT

# install Golang 1.22
RUN <<'EOT'
set -e
echo "::group::Install Golang 1.22"
( set -euxo pipefail

  dnf install -y golang
  dnf clean all
  rm -rf /var/log/* /var/cache/dnf

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
( set -euxo pipefail

  curl -sSL https://rpm.nodesource.com/setup_22.x | bash -
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
( set -euxo pipefail

  # install AWS CLI v2: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html
  cd /tmp
  curl -sSLo awscliv2.zip https://awscli.amazonaws.com/awscli-exe-linux-$(uname -m).zip
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
  cd /tmp
  ARCH=$(uname -m | sed 's/aarch64/arm64/') # must be x86_64 or arm64
  curl -sSLO https://s3.amazonaws.com/mountpoint-s3-release/latest/$ARCH/mount-s3.rpm
  dnf install -y ./mount-s3.rpm
  dnf clean all
  rm -rf /var/log/* /var/cache/dnf *.rpm
  mount-s3 --version
)
echo "::endgroup::"
EOT

# install Kubernetes tools
RUN <<'EOT'
set -e
echo "::group::Install Kubernetes tools"
( set -euxo pipefail

  # use the appropriate binaries for this multi-arch Docker image
  ARCH=$(uname -m | sed -e 's/aarch64/arm64/' -e 's/x86_64/amd64/')

  # install Kubectl: https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/
  cd /usr/local/bin
  REL="https://dl.k8s.io/release"
  VER=$(curl -sL $REL/stable.txt)
  curl -sSLO $REL/$VER/bin/linux/$ARCH/kubectl
  chmod +x kubectl
  kubectl version --client

  # install Kubeconform: https://github.com/yannh/kubeconform#installation
  cd /usr/local/bin
  REL="https://github.com/yannh/kubeconform/releases/latest"
  curl -sSL $REL/download/kubeconform-linux-$ARCH.tar.gz | tar -xz --no-same-owner kubeconform
  ln -s /usr/local/bin/kubeconform /usr/local/bin/kubectl-conform
  kubectl conform -v

  # install Krew: https://krew.sigs.k8s.io/docs/user-guide/setup/install/
  cd /tmp
  REL="https://github.com/kubernetes-sigs/krew/releases/latest"
  KREW=krew-linux_$ARCH
  curl -sSL $REL/download/$KREW.tar.gz | tar -xz ./$KREW
  ./$KREW install krew
  rm -f ./$KREW
  # /root/.krew/bin is already in $PATH via Dockerfile ENV command
  kubectl krew version

  # install kube-score: https://github.com/zegl/kube-score#installation
  if [ $ARCH == amd64 ]; then
    # can't install kube-score on ARM via Krew yet:
    # https://github.com/zegl/kube-score/issues/594
    kubectl krew install score
    kubectl score version
  fi

  # install Helm: https://helm.sh/docs/intro/install/
  cd /usr/local/bin
  REL="https://github.com/helm/helm/releases/latest"
  VER=$(curl -Is $REL | sed -En 's/^location:.+\/tag\/(.+)\r$/\1/p')
  curl -sSL https://get.helm.sh/helm-$VER-linux-$ARCH.tar.gz | tar -xz --strip 1 linux-$ARCH/helm
  helm version

  # install Helm plugins
  helm plugin install https://github.com/databus23/helm-diff
  helm plugin install https://github.com/erhhung/helm-ssm
  rm -rf /root/.cache
)
echo "::endgroup::"
EOT

CMD ["bash", "--login"]
