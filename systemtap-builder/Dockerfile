FROM rockylinux:9

RUN yum update -y && \
        yum install -y boost-devel diffutils elfutils-devel g++ gettext git patch

ARG SOURCE_BRANCH=master
RUN git clone --branch $SOURCE_BRANCH --depth 1 https://sourceware.org/git/systemtap.git

# Patch out a not-always-needed link to libboost_system
# to simplify the build output's runtime dependencies.
COPY remove-libboost_system.patch /
RUN patch -p0 < /remove-libboost_system.patch

ARG INSTALL_PREFIX=/var/systemtap
RUN <<EOF cat > /build-systemtap.sh
#!/usr/bin/env sh
set -e

cd systemtap && \
        ./configure --prefix=$INSTALL_PREFIX && \
        make && \
        make install
EOF
RUN chmod +x /build-systemtap.sh
ENTRYPOINT ["/build-systemtap.sh"]
