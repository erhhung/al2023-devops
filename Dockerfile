# =========================================================
FROM public.ecr.aws/amazonlinux/amazonlinux:2023 AS builder
# =========================================================

# NOTE: AL2023 GA version includes components from Fedora 34, 35, and 36:
# https://docs.aws.amazon.com/linux/al2023/ug/relationship-to-fedora.html

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
COPY --from=builder /usr/local/include/     /usr/local/include/
COPY --from=builder /usr/local/share/       /usr/local/share/
COPY --from=builder /usr/local/etc/         /usr/local/etc/
COPY --from=builder /etc/alternatives/      /etc/alternatives/
COPY --from=builder /var/lib/alternatives/  /var/lib/alternatives/
COPY --from=builder /root/.docker/          /root/.docker/

# configure locale; non-"en_US" locales will be purged from
# /usr/{lib,share}/locale by scripts/install/linux-utils.sh
COPY config/locale.conf /etc/

# copy various dotfiles
COPY config/.* /root/

# =======================================================
FROM public.ecr.aws/amazonlinux/amazonlinux:2023 AS final
# =======================================================

#LABEL name="al2023-devops"
#LABEL description="Amazon Linux 2023 with Python 3.13, Go 1.24, Node.js 22, AWS CLI, CDK, CDK8s, Terraform, Ansible, Docker, Kubectl, Krew, Helm, Argo CD, and utilities like jq, jo, yq, jsonnet, and Just"
#LABEL maintainer="erhhung@gmail.com"

ENV TERM="xterm-256color"
ENV PYGMENT_STYLE="one-dark"
ENV PATH="/usr/local/poetry/bin:$PATH:/root/.krew/bin"
ENV JSII_SILENCE_WARNING_DEPRECATED_NODE_VERSION="1"
ENV CDK8S_CHECK_UPGRADE="false"
ENV TF_CLI_ARGS_init="-compact-warnings"
ENV TF_CLI_ARGS_plan="-compact-warnings"
ENV TF_CLI_ARGS_apply="-compact-warnings"

# Copy all consolidated files
COPY --from=consolidator / /

WORKDIR /root

# install Linux utilities
RUN --mount=type=bind,source=scripts/install/linux-utils.sh,target=/tmp/install.sh /tmp/install.sh

# install Python tools
RUN --mount=type=bind,source=scripts/install/python-tools.sh,target=/tmp/install.sh /tmp/install.sh

# install Go 1.24
RUN --mount=type=bind,source=scripts/install/go.sh,target=/tmp/install.sh /tmp/install.sh

# install Node.js 22
RUN --mount=type=bind,source=scripts/install/node.sh,target=/tmp/install.sh /tmp/install.sh

# install AWS tools
RUN --mount=type=bind,source=scripts/install/aws-tools.sh,target=/tmp/install.sh /tmp/install.sh

# install infra tools
RUN --mount=type=bind,source=scripts/install/infra-tools.sh,target=/tmp/install.sh /tmp/install.sh

# install OCI image tools
RUN --mount=type=bind,source=scripts/install/oci-tools.sh,target=/tmp/install.sh /tmp/install.sh

# install Kubernetes tools
RUN --mount=type=bind,source=scripts/install/k8s-tools.sh,target=/tmp/install.sh /tmp/install.sh

# generate /root/.versions.json containing manifest
# of all installed tools and their current versions
RUN --mount=type=bind,source=scripts/versions.sh,target=/tmp/versions.sh /tmp/versions.sh

CMD ["bash", "--login"]
