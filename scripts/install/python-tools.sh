#!/usr/bin/env bash

# shellcheck disable=SC2148 # Tips depend on target shell

echo "::group::Install Python tools"
trap 'echo "::endgroup::"' EXIT
set -euxo pipefail

# install Poetry: https://python-poetry.org/docs/#installing-with-the-official-installer
curl -fsSL https://install.python-poetry.org | \
  POETRY_HOME="/usr/local/poetry" python3 -
# /usr/local/poetry/bin is already in $PATH via Dockerfile ENV command
poetry -V

# install uv: https://docs.astral.sh/uv/getting-started/installation/
curl -fsSL https://astral.sh/uv/install.sh | XDG_BIN_HOME=/usr/local/bin sh
uv -V

# install pipx (for both system Python 3.9 in
# /usr/bin and Python 3.13 in /usr/local/bin)
/usr/bin/pip3 install --prefix /usr --no-cache-dir pipx 2> /dev/null
/usr/local/bin/pip3 install --no-cache-dir --root-user-action=ignore pipx
pipx --version

# install Pygments, and ansitable
pip3 install --no-cache-dir --root-user-action=ignore colored \
  pygments ansitable
rm -rf /root/.cache
pygmentize -V
