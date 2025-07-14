#!/usr/bin/env sh
set -e

export RUNTIME_VERSION=ubuntu-24.04
export KERNEL_VERSION=$(uname -r)
./systemtap-runner-common.sh $@
