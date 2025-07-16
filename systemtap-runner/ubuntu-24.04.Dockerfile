FROM ubuntu:24.04

# Fetch s6-overlay init system setup files.
ARG S6_OVERLAY_VERSION
ADD https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-noarch.tar.xz /tmp
ADD https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-x86_64.tar.xz /tmp

RUN mkdir -p /etc/services.d/stap
ADD stap-run.sh /etc/services.d/stap/run

# Force a rebuild of this container image if the kernel version changes.
# Debug symbols MUST be redownloaded for the specific kernel version!
ARG KERNEL_VERSION
ENV KERNEL_VERSION_ARG=${KERNEL_VERSION}

ENV DEBIAN_FRONTEND=noninteractive

# Prepare apt to retrieve distro (especially kernel) debug symbols.
# The container image deliberately prepares these symbols ahead of time
# ISNTEAD OF waiting for debuginfod retrieval at runtime.
#
# Suites must reference the ubuntu release version's name,
# e.g. 24.04 => "noble"
RUN apt update && \
	apt install -y ubuntu-dbgsym-keyring
RUN <<EOF cat > /etc/apt/sources.list.d/ddebs.sources
Types: deb
URIs: http://ddebs.ubuntu.com/
Suites: noble noble-updates noble-proposed 
Components: main restricted universe multiverse
Signed-by: /usr/share/keyrings/ubuntu-dbgsym-keyring.gpg
EOF

# Runtime dependencies: the `stap-prep` script doesn't handle everything!
# - `lsb_release` (from lsb-release) is needed by stap-prep itself.
# - `gcc-13` (from gcc-13) is missed by stap-prep.
# - `libdw.so.1` (from libdw1t64) is missed by stap-prep.
# - xz archive support (from xz-utils) is needed to decompress s6-overlay.
RUN apt update && \
	apt install -y lsb-release gcc-13 libdw1t64 xz-utils

# Add + unpack the previously-built systemtap package,
# then run `stap-prep` to prepare remaining runtime dependencies.
ARG SYSTEMTAP_PREFIX
ADD .systemtap-build.tar.gz /
ENV PATH="$PATH:/${SYSTEMTAP_PREFIX}/bin"
RUN stap-prep

RUN tar -C / -Jxpf /tmp/s6-overlay-noarch.tar.xz
RUN tar -C / -Jxpf /tmp/s6-overlay-x86_64.tar.xz
ENTRYPOINT ["/init"]
