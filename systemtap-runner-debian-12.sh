#!/usr/bin/env sh
set -e

export RUNTIME_VERSION=debian-12
export KERNEL_VERSION=$(uname -r)
./systemtap-runner-common.sh $@
