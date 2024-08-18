al2023-devops
-------------

Multi-arch (x86_64/amd64 and aarch64/arm64) Docker image based on **Amazon Linux 2023** for DevOps use cases on AWS, such as CI/CD pipelines and admininistration of EKS workloads, including **interactive shell usage**.

## Bundled Tools

Includes the following components:
- [Python 3.12](https://www.python.org/downloads)
- [Go 1.22](https://go.dev/dl)
- [Node.js 22](https://nodejs.org/en/download)
- [Poetry](https://python-poetry.org/)
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide)
- [AWS CDK](https://docs.aws.amazon.com/cdk/v2/guide) and [CDK8s](https://cdk8s.io/)
- [Mountpoint for Amazon S3](https://docs.aws.amazon.com/AmazonS3/latest/userguide/mountpoint.html)
- [Docker CLI](https://www.docker.com/products/cli)
  - Plugins: [BuildX](https://github.com/docker/buildx) and [Compose](https://docs.docker.com/compose)
- [Kubectl](https://kubernetes.io/docs/tasks/tools) and [Krew](https://krew.sigs.k8s.io/)
  - Plugins: [Kubeconform](https://github.com/yannh/kubeconform) and [kube-score](https://github.com/zegl/kube-score)
- [Helm](https://helm.sh/)
  - Plugins: [helm-diff](https://github.com/databus23/helm-diff) and [helm-ssm](https://github.com/codacy/helm-ssm)

As well as the following utilities:
- [jq](https://stedolan.github.io/jq), [jo](https://github.com/jpmens/jo), and [yq](https://mikefarah.gitbook.io/yq)
- [GNU Parallel](https://savannah.gnu.org/projects/parallel)
- Common Linux utilities: `which`, `find`, `free`, `tar`, `gzip`, `xz`, `bzip`, `unzip`, `wget`, `git`, `pwgen`,  
  `md5sum`, `envsubst` (GNU gettext), `sponge`/`ts`/... ([moreutils](https://joeyh.name/code/moreutils/)), `bc`, `openssl`, `nmap`, `tmux`, `vim`
- [Pygments](https://pygments.org/)
- [Just](https://just.systems/man/en)
- [Tini](https://github.com/krallin/tini)

## Prebuilt Images

Size is approximately 2.5 GB.

Images are available in the following repositories:
- Docker Hub: [`docker.io/erhhung/al2023-devops`](https://hub.docker.com/repository/docker/erhhung/al2023-devops)
- GitHub Container Registry: [`ghcr.io/erhhung/al2023-devops`](https://github.com/users/erhhung/packages/container/al2023-devops)

Version information about installed components can be found in the Docker image at `/root/.versions.json`.
