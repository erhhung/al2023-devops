# [al2023-devops](https://github.com/erhhung/al2023-devops)

Multi-arch (x86_64/amd64 and aarch64/arm64) Docker image based on **Amazon Linux 2023** for DevOps use cases on AWS, such as CI/CD pipelines and manual admininistration of EKS workloads, including **interactive shell usage**.

## Bundled Tools

Includes the following components:
- [Python 3.13](https://www.python.org/downloads)
  - [Poetry](https://python-poetry.org/)
  - [pipx](https://pipx.pypa.io/)
  - [uv](https://docs.astral.sh/uv/)
- [Go 1.23](https://go.dev/dl)
- [Node.js 22](https://nodejs.org/en/download)
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide)
- [AWS CDK](https://docs.aws.amazon.com/cdk/v2/guide) and
  [CDK8s](https://cdk8s.io/)
- [Mountpoint for Amazon S3](https://docs.aws.amazon.com/AmazonS3/latest/userguide/mountpoint.html)
- [Terraform](https://developer.hashicorp.com/terraform)
- [Ansible](https://docs.ansible.com/)
- [Docker CLI](https://www.docker.com/products/cli)
  - [BuildX](https://github.com/docker/buildx)
  - [Compose](https://docs.docker.com/compose)
- [Dive](https://github.com/wagoodman/dive) and
  [MinToolkit/Mint](https://github.com/mintoolkit/mint)
- [Kubectl](https://kubernetes.io/docs/tasks/tools) and
  [Krew](https://krew.sigs.k8s.io/)
  - [kubectl-grep](https://github.com/guessi/kubectl-grep)
  - [kubectl-argo-rollouts](https://argo-rollouts.readthedocs.io/en/stable/)
  - [Kubeconform](https://github.com/yannh/kubeconform)
  - [kube-score](https://github.com/zegl/kube-score)
- [kind](https://kind.sigs.k8s.io/) and [vCluster](https://www.vcluster.com/)
- [Helm](https://helm.sh/)
  - [helm-docs](https://github.com/norwoodj/helm-docs)
  - [helm-diff](https://github.com/databus23/helm-diff)
  - [helm-ssm](https://github.com/codacy/helm-ssm)
  - [Helmfile](https://github.com/helmfile/helmfile)
- [Argo CD](https://argo-cd.readthedocs.io/en/stable/)

As well as the following utilities:
- [jq](https://stedolan.github.io/jq),
  [jo](https://github.com/jpmens/jo), and
  [yq](https://mikefarah.gitbook.io/yq)
- [jsonnet](https://jsonnet.org/)
- [GNU Parallel](https://savannah.gnu.org/projects/parallel)
- Common Linux utilities: `which`, `find`, `free`, `tar`, `gzip`, `xz`, `bzip`, `unzip`, `wget`, `git`, `pwgen`,  
  `md5sum`, `envsubst` (GNU gettext), `sponge`/`ts`/... ([moreutils](https://joeyh.name/code/moreutils/)), `bc`,
  `openssl`, `nmap`, `tmux`, `vim`
- [Pygments](https://pygments.org/)
- [Just](https://just.systems/man/en)
- [Tini](https://github.com/krallin/tini)

## Prebuilt Images

Size is approximately 4 GB _(too chubby, I know — see the [To-Do](#to-do) section)._

Images are available in the following repositories:
- Docker Hub: [`docker.io/erhhung/al2023-devops`](https://hub.docker.com/repository/docker/erhhung/al2023-devops)
- GitHub Container Registry: [`ghcr.io/erhhung/al2023-devops`](https://github.com/erhhung/al2023-devops/pkgs/container/al2023-devops)

Version information about the installed components can be found inside the Docker image at `/root/.versions.json`.

## To-Do

The current "All-in-One" image is getting too bloated, so there's a need to create specialized versions, like a slimmed-down image just for CI/CD pipelines, and a separate image for launching ad-hoc containers for manual administration and debugging. It's also unlikely that a single CI/CD pipeline stage would need all language environments, as Python and Go are especially chubby.
