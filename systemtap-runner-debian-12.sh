#!/usr/bin/env sh
set -e

export RUNTIME_VERSION=debian-12
./systemtap-runner-common.sh $@
