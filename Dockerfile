# =========================================================
FROM public.ecr.aws/amazonlinux/amazonlinux:2023 AS builder
# =========================================================

# NOTE: AL2023 GA version includes components from Fedora 34, 35, and 36:
# https://docs.aws.amazon.com/linux/al2023/ug/relationship-to-fedora.html

SHELL ["/bin/bash", "-c"]

# install common build tools
RUN --mount=type=bind,source=scripts/build/common.sh,target=/tmp/build.sh /tmp/build.sh

# build Python 3.13: https://www.build-python-from-source.com/
RUN --mount=type=bind,source=scripts/build/python.sh,target=/tmp/build.sh /tmp/build.sh

# build moreutils: https://joeyh.name/code/moreutils
RUN --mount=type=bind,source=scripts/build/moreutils.sh,target=/tmp/build.sh /tmp/build.sh

# build GNU parallel: https://www.gnu.org/software/parallel
RUN --mount=type=bind,source=scripts/build/parallel.sh,target=/tmp/build.sh /tmp/build.sh

# build tini: https://github.com/krallin/tini
RUN --mount=type=bind,source=scripts/build/tini.sh,target=/tmp/build.sh /tmp/build.sh

# build jo: https://github.com/jpmens/jo
RUN --mount=type=bind,source=scripts/build/jo.sh,target=/tmp/build.sh /tmp/build.sh

# build buildah: https://github.com/containers/buildah
RUN --mount=type=bind,source=scripts/build/buildah.sh,target=/tmp/build.sh /tmp/build.sh

# build skopeo: https://github.com/containers/skopeo
RUN --mount=type=bind,source=scripts/build/skopeo.sh,target=/tmp/build.sh /tmp/build.sh

# copy gomplate: https://docs.gomplate.ca/installing#use-inside-a-container
COPY --from=hairyhenderson/gomplate:stable /gomplate /usr/local/bin/

# copy Docker binaries, including BuildX and Compose
COPY --from=public.ecr.aws/docker/library/docker:dind /usr/local/bin/docker                  /usr/local/bin/
COPY --from=public.ecr.aws/docker/library/docker:dind /usr/local/libexec/docker/cli-plugins/ /usr/local/bin/

# install Docker BuildX and Compose as user plugins
RUN --mount=type=bind,source=scripts/install/docker.sh,target=/tmp/install.sh /tmp/install.sh

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
ENV PATH="/usr/local/poetry/bin:$PATH:/root/.local/bin:/root/.krew/bin"

ENV LANG="en_US.UTF-8"
ENV LANGUAGE="en_US:en"
ENV LC_ALL="en_US.UTF-8"
ENV LC_COLLATE="C"

SHELL ["/bin/bash", "-c"]

# Copy all consolidated files
COPY --from=consolidator / /

WORKDIR /root

ENV PYGMENT_STYLE="one-dark"

# install Linux utilities
RUN --mount=type=bind,source=scripts/install/linux-utils.sh,target=/tmp/install.sh /tmp/install.sh

# install Python tools
RUN --mount=type=bind,source=scripts/install/python-tools.sh,target=/tmp/install.sh /tmp/install.sh

# install Go 1.25
RUN --mount=type=bind,source=scripts/install/go.sh,target=/tmp/install.sh /tmp/install.sh

ENV JSII_SILENCE_WARNING_DEPRECATED_NODE_VERSION="1"

# install Node.js 22
RUN --mount=type=bind,source=scripts/install/node.sh,target=/tmp/install.sh /tmp/install.sh

ENV CDK8S_CHECK_UPGRADE="false"

# install AWS tools
RUN --mount=type=bind,source=scripts/install/aws-tools.sh,target=/tmp/install.sh /tmp/install.sh

ENV TF_CLI_ARGS_init="-compact-warnings"
ENV TF_CLI_ARGS_plan="-compact-warnings"
ENV TF_CLI_ARGS_apply="-compact-warnings"

# install infra tools
RUN --mount=type=bind,source=scripts/install/infra-tools.sh,target=/tmp/install.sh /tmp/install.sh

# https://man.archlinux.org/man/extra/buildah/buildah-bud
ENV BUILDAH_ISOLATION="chroot"

# install OCI image tools
RUN --mount=type=bind,source=scripts/install/oci-tools.sh,target=/tmp/install.sh /tmp/install.sh

# HELM_BIN is required by helm-git
ENV HELM_BIN="/usr/local/bin/helm"
ENV HELM_PLUGINS="/root/.local/share/helm/plugins"

# install Kubernetes tools
RUN --mount=type=bind,source=scripts/install/k8s-tools.sh,target=/tmp/install.sh /tmp/install.sh

# generate /root/.versions.json containing manifest
# of all installed tools and their current versions
RUN --mount=type=bind,source=scripts/versions.sh,target=/tmp/versions.sh /tmp/versions.sh

CMD ["bash", "--login"]
