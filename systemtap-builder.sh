#!/usr/bin/env sh
set -e

# Specify a systemtap release version (git branch) for the builder to use.
# If unspecified, the builder will use latest/HEAD systemtap sources.
SYSTEMTAP_RELEASE=5.3

# Specify a path prefix for the builder's output.
# A runtime environment will need to 
SYSTEMTAP_PREFIX=/var/systemtap-5.3

# The builder image will produce systemtap build outputs in BUILD_DIR.
BUILD_DIR=${BUILD_DIR:-.}
mkdir -p ${BUILD_DIR}
docker build \
	 -f systemtap-builder/Dockerfile \
	 -t systemtap-builder \
	 --build-arg SOURCE_BRANCH=release-${SYSTEMTAP_RELEASE} \
	 --build-arg INSTALL_PREFIX=${SYSTEMTAP_PREFIX} \
	 ./systemtap-builder
docker run --rm -v $(realpath ${BUILD_DIR}):/systemtap-builddir systemtap-builder

# Output of the docker run:
# - A simple text file describing the path prefix for installing systemtap.
#   If BUILD_PREFIX_FILEPATH was specified, the prefix will be copied there.
# - A compressed archive of the systemtap build files, to place in that prefix.
#   If BUILD_ARCHIVE_FILEPATH was specified, the archive will be copied there.
# These outputs can be used to set up systemtap in a runtime environment.

BUILD_PREFIX_FILEPATH=${BUILD_PREFIX_FILEPATH:-.systemtap-build.prefix}
cp ${BUILD_DIR}/.systemtap-build.prefix ${BUILD_PREFIX_FILEPATH}

BUILD_ARCHIVE_FILEPATH=${BUILD_ARCHIVE_FILEPATH:-.systemtap-build.tar.gz}
cp ${BUILD_DIR}/.systemtap-build.tar.gz ${BUILD_ARCHIVE_FILEPATH}
