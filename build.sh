#!/usr/bin/env bash

# USAGE: ./build.sh [extra docker build args]

get_label() {
  sed -En "s/LABEL $1=\"(.+)\"/\1/p" Dockerfile
}

repo=$(get_label name)
date=$(get_label build_date)
 src=${repo}:${date}
 log=${0/%.sh/.log}

aws ecr-public get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin public.ecr.aws

docker build -t $repo:$date --progress plain "$@" . | tee $log
