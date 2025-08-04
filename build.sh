#!/bin/bash
set -eux
set -o pipefail

RUST_VERSION=1.88.0

docker buildx build \
    --build-arg TOOLCHAIN=$RUST_VERSION \
    --platform linux/amd64 \
    -t jszulc/rust-musl-builder:$RUST_VERSION \
    -t jszulc/rust-musl-builder:latest \
    -o type=image \
    .
#   -o type=registry for pushing to docker hub

docker run --rm jszulc/rust-musl-builder:$RUST_VERSION sh -c "cargo --version && rustc --version && rustup --version"
