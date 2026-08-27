# =========================================================
FROM public.ecr.aws/amazonlinux/amazonlinux:2023 AS builder
# =========================================================

# NOTE: AL2023 GA version includes components from Fedora 34, 35, and 36:
# https://docs.aws.amazon.com/linux/al2023/ug/relationship-to-fedora.html

SHELL ["/bin/bash", "-c"]

# install common build tools
RUN --mount=type=bind,source=scripts/build/common.sh,target=/mnt/build.sh \
  --mount=type=tmpfs,target=/tmp /mnt/build.sh

# build GNU Make first so other builds can use it: https://www.gnu.org/software/make
RUN --mount=type=bind,source=scripts/build/make.sh,target=/mnt/build.sh \
  --mount=type=tmpfs,target=/tmp /mnt/build.sh

# build GNU Parallel: https://www.gnu.org/software/parallel
RUN --mount=type=bind,source=scripts/build/parallel.sh,target=/mnt/build.sh \
  --mount=type=tmpfs,target=/tmp /mnt/build.sh

# build moreutils: https://joeyh.name/code/moreutils
RUN --mount=type=bind,source=scripts/build/moreutils.sh,target=/mnt/build.sh \
  --mount=type=tmpfs,target=/tmp /mnt/build.sh

# build jo: https://github.com/jpmens/jo
RUN --mount=type=bind,source=scripts/build/jo.sh,target=/mnt/build.sh \
  --mount=type=tmpfs,target=/tmp /mnt/build.sh

# build Python 3.14: https://www.build-python-from-source.com/
RUN --mount=type=bind,source=scripts/build/python.sh,target=/mnt/build.sh \
  --mount=type=tmpfs,target=/tmp /mnt/build.sh

# build buildah: https://github.com/containers/buildah
RUN --mount=type=bind,source=scripts/build/buildah.sh,target=/mnt/build.sh \
  --mount=type=tmpfs,target=/tmp /mnt/build.sh

# build skopeo: https://github.com/containers/skopeo
RUN --mount=type=bind,source=scripts/build/skopeo.sh,target=/mnt/build.sh \
  --mount=type=tmpfs,target=/tmp /mnt/build.sh

# build tini: https://github.com/krallin/tini
RUN --mount=type=bind,source=scripts/build/tini.sh,target=/mnt/build.sh \
  --mount=type=tmpfs,target=/tmp /mnt/build.sh

# copy gomplate: https://docs.gomplate.ca/installing#use-inside-a-container
COPY --from=hairyhenderson/gomplate:stable /gomplate /usr/local/bin/

# copy Docker binaries, including BuildX and Compose (but no daemon!)
COPY --from=public.ecr.aws/docker/library/docker:dind /usr/local/bin/docker                  /usr/local/bin/
COPY --from=public.ecr.aws/docker/library/docker:dind /usr/local/libexec/docker/cli-plugins/ /usr/local/bin/

# install Docker BuildX and Compose as user plugins
RUN --mount=type=bind,source=scripts/install/docker.sh,target=/mnt/install.sh \
  --mount=type=tmpfs,target=/tmp /mnt/install.sh

# remove debugging symbols & sections from executables
RUN --mount=type=bind,source=scripts/install/helpers.sh,target=/mnt/helpers.sh \
  --mount=type=tmpfs,target=/tmp . /mnt/helpers.sh && strip_bins /usr/local/bin

# ==========================
FROM scratch AS consolidator
# ==========================

# copy directories installed to in the builder stage
COPY --from=builder /usr/local/bin/         /usr/local/bin/
COPY --from=builder /usr/local/lib/         /usr/local/lib/
COPY --from=builder /usr/local/libexec/     /usr/local/libexec/
COPY --from=builder /usr/local/include/     /usr/local/include/
COPY --from=builder /usr/local/share/       /usr/local/share/
COPY --from=builder /usr/local/etc/         /usr/local/etc/
COPY --from=builder /etc/alternatives/      /etc/alternatives/
COPY --from=builder /var/lib/alternatives/  /var/lib/alternatives/
COPY --from=builder /root/.docker/          /root/.docker/

# configure locale; non-"en_US" locales will be purged from
# /usr/{lib,share}/locale by scripts/install/linux-utils.sh
COPY --link config/locale.conf /etc/

# copy dotfiles and scripts
COPY --link config/.* /root/
COPY --link scripts/usrlocalbin/* /usr/local/bin/

# =======================================================
FROM public.ecr.aws/amazonlinux/amazonlinux:2023 AS final
# =======================================================

ENV TERM="xterm-256color"
ENV XDG_CONFIG_HOME="/root/.config"
ENV XDG_CACHE_HOME="/root/.cache"
ENV XDG_DATA_HOME="/root/.local/share"
ENV XDG_STATE_HOME="/root/.local/state"
ENV PATH="$PATH:/root/.local/bin"

ENV LANG="en_US.UTF-8"
ENV LANGUAGE="en_US:en"
ENV LC_COLLATE="C"

SHELL ["/bin/bash", "-c"]

# Copy all consolidated files
COPY --from=consolidator / /

WORKDIR /root

ENV PYGMENT_STYLE="one-dark"

# install Linux utilities
RUN --mount=type=bind,source=scripts/install/helpers.sh,target=/mnt/helpers.sh \
  --mount=type=bind,source=scripts/install/linux-utils.sh,target=/mnt/install.sh \
  --mount=type=tmpfs,target=/tmp . /mnt/helpers.sh && /mnt/install.sh && \
  strip_bins /usr/local/bin

ENV PATH="$PATH:/usr/local/poetry/bin"

# install Python tools
RUN --mount=type=bind,source=scripts/install/helpers.sh,target=/mnt/helpers.sh \
  --mount=type=bind,source=scripts/install/python-tools.sh,target=/mnt/install.sh \
  --mount=type=tmpfs,target=/tmp . /mnt/helpers.sh && /mnt/install.sh && \
  strip_bins /usr/local/bin

ENV JSII_SILENCE_WARNING_DEPRECATED_NODE_VERSION="1"
ENV PNPM_HOME="$XDG_DATA_HOME/pnpm"
ENV PNPM_STORE_DIR="$PNPM_HOME/store"
ENV PATH="$PATH:$PNPM_HOME/bin"

# install Node.js 24
RUN --mount=type=bind,source=scripts/install/helpers.sh,target=/mnt/helpers.sh \
  --mount=type=bind,source=scripts/install/node.sh,target=/mnt/install.sh \
  --mount=type=tmpfs,target=/tmp . /mnt/helpers.sh && /mnt/install.sh && \
  strip_bins /usr/local/bin

ENV JAVA_TOOL_OPTIONS="-Djava.awt.headless=true"
ENV JAVA_HOME="/usr/lib/jvm/java-26-amazon-corretto"
ENV PATH="$PATH:$JAVA_HOME/bin:/usr/local/maven/bin"

# install Java JDK 26
RUN --mount=type=bind,source=scripts/install/helpers.sh,target=/mnt/helpers.sh \
  --mount=type=bind,source=scripts/install/java.sh,target=/mnt/install.sh \
  --mount=type=tmpfs,target=/tmp . /mnt/helpers.sh && /mnt/install.sh && \
  strip_bins /usr/local/bin

# install Go 1.26
RUN --mount=type=bind,source=scripts/install/helpers.sh,target=/mnt/helpers.sh \
  --mount=type=bind,source=scripts/install/go.sh,target=/mnt/install.sh \
  --mount=type=tmpfs,target=/tmp . /mnt/helpers.sh && /mnt/install.sh && \
  strip_bins /usr/local/bin

# install development tools
RUN --mount=type=bind,source=scripts/install/helpers.sh,target=/mnt/helpers.sh \
  --mount=type=bind,source=scripts/install/dev-tools.sh,target=/mnt/install.sh \
  --mount=type=tmpfs,target=/tmp . /mnt/helpers.sh && /mnt/install.sh && \
  strip_bins /usr/local/bin

ENV CDK8S_CHECK_UPGRADE="false"

# install AWS tools
RUN --mount=type=bind,source=scripts/install/helpers.sh,target=/mnt/helpers.sh \
  --mount=type=bind,source=scripts/install/aws-tools.sh,target=/mnt/install.sh \
  --mount=type=tmpfs,target=/tmp . /mnt/helpers.sh && /mnt/install.sh && \
  strip_bins /usr/local/bin

ENV TF_CLI_ARGS_init="-compact-warnings"
ENV TF_CLI_ARGS_plan="-compact-warnings"
ENV TF_CLI_ARGS_apply="-compact-warnings"

# install infra tools
RUN --mount=type=bind,source=scripts/install/helpers.sh,target=/mnt/helpers.sh \
  --mount=type=bind,source=scripts/install/infra-tools.sh,target=/mnt/install.sh \
  --mount=type=tmpfs,target=/tmp . /mnt/helpers.sh && /mnt/install.sh && \
  strip_bins /usr/local/bin

# https://man.archlinux.org/man/extra/buildah/buildah-bud
ENV BUILDAH_ISOLATION="chroot"

# install OCI image tools
RUN --mount=type=bind,source=scripts/install/helpers.sh,target=/mnt/helpers.sh \
  --mount=type=bind,source=scripts/install/oci-tools.sh,target=/mnt/install.sh \
  --mount=type=tmpfs,target=/tmp . /mnt/helpers.sh && /mnt/install.sh && \
  strip_bins /usr/local/bin

# HELM_BIN is required by helm-git
ENV HELM_BIN="/usr/local/bin/helm"
ENV HELM_PLUGINS="$XDG_DATA_HOME/helm/plugins"
ENV PATH="$PATH:/root/.krew/bin"

# install Kubernetes tools
RUN --mount=type=bind,source=scripts/install/helpers.sh,target=/mnt/helpers.sh \
  --mount=type=bind,source=scripts/install/k8s-tools.sh,target=/mnt/install.sh \
  --mount=type=tmpfs,target=/tmp . /mnt/helpers.sh && /mnt/install.sh && \
  strip_bins /usr/local/bin

# generate /root/.versions.json containing manifest
# of all installed tools and their current versions
RUN --mount=type=bind,source=scripts/versions.sh,target=/mnt/versions.sh \
  --mount=type=tmpfs,target=/tmp /mnt/versions.sh

CMD ["bash", "--login"]
