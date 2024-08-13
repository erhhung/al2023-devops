#!/usr/bin/env bash

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
 src=$repo:latest
 log=${0/%.sh/.log}

# build for local platform only by default
set -- $plat "$@"

aws ecr-public get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin public.ecr.aws

# docker buildx create --name multi-builder --bootstrap --use
# https://docs.docker.com/build/building/multi-platform/#building-multi-platform-images
docker buildx build "$@" --tag $src --load --progress plain . 2>&1 | \
  sed -Eu 's/^(#[0-9]+ [0-9.]+ )(::(end)?group::.*)$/\2/' | tee -a $log
