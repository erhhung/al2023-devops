#!/usr/bin/env bash

# shellcheck disable=SC2148 # Tips depend on target shell
# shellcheck disable=SC2086 # Double quote prevent globbing

# build script for local testing; GitHub Actions is
# used for CI build based on year.month (YY.MM) tag

# USAGE: ./build.sh [extra docker buildx build args]

get_label() {
  sed -En "s/^.*LABEL $1=\"(.+)\"/\1/p" Dockerfile
}

get_platform() {
  if [[ " $* " != *" --platform "* ]]; then
    arch=$(uname -m | sed -e 's/aarch64/arm64/' -e 's/x86_64/amd64/')
    echo "--platform linux/$arch"
  fi
}

repo=$(get_label name)
plat=$(get_platform "$@")
 tag=${repo:-al2023-devops}:latest
 log=${0/%.sh/.log}

# build for local platform only by default
set -- $plat "$@"

aws ecr-public get-login-password --profile github --region us-east-1 | \
  docker login --username AWS --password-stdin public.ecr.aws

# docker buildx create --name multi-builder --bootstrap --use
# https://docs.docker.com/build/building/multi-platform/#building-multi-platform-images
docker buildx build "$@" --builder multi-builder \
  --tag "$tag" --load --progress plain . 2>&1  | \
  sed -Eu 's/^(#[0-9]+ [0-9.]+ )(::(end)?group::.*)$/\2/' | tee -a "$log"
