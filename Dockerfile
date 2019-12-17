#######################
# Extra builder for healthchecker
#######################
ARG           BUILDER_BASE=dubodubonduponey/base:builder
ARG           RUNTIME_BASE=dubodubonduponey/base:runtime
# hadolint ignore=DL3006
FROM          --platform=$BUILDPLATFORM $BUILDER_BASE                                                                   AS builder-healthcheck

ARG           HEALTH_VER=51ebf8ca3d255e0c846307bf72740f731e6210c3

WORKDIR       $GOPATH/src/github.com/dubo-dubon-duponey/healthcheckers
RUN           git clone git://github.com/dubo-dubon-duponey/healthcheckers .
RUN           git checkout $HEALTH_VER
RUN           arch="${TARGETPLATFORM#*/}"; \
              env GOOS=linux GOARCH="${arch%/*}" go build -v -ldflags "-s -w" -o /dist/boot/bin/rtsp-health ./cmd/rtsp

#######################
# Building image
#######################
# hadolint ignore=DL3006
FROM          $BUILDER_BASE                                                                                             AS builder

WORKDIR       /build

# shairport-sync: v3.3.2
ARG           SHAIRPORT_VER=ca9b2ff3bc1630c9de95f4555d4398d1a33ec2a3
# with sigsegv fixes
ARG           SHAIRPORT_VER=0e85ec370a08c3443b0b9e28707d1022efc0f74f
# ALAC from apple: Feb 2019
ARG           ALAC_VERSION=5d6d836ee5b025a5e538cfa62c88bc5bced506ed

RUN           git clone git://github.com/mikebrady/alac.git
RUN           git clone git://github.com/mikebrady/shairport-sync
RUN           git -C alac           checkout $ALAC_VERSION
RUN           git -C shairport-sync checkout $SHAIRPORT_VER

RUN           apt-get install -qq --no-install-recommends \
                libasound2-dev=1.1.8-1 \
                libpopt-dev=1.16-12 \
                libsoxr-dev=0.1.2-3 \
                libconfig-dev=1.5-0.4 \
                libssl-dev=1.1.1d-0+deb10u2 \
                libcrypto++-dev=5.6.4-8

# ALAC (from apple)
WORKDIR       /build/alac
RUN           mkdir -p m4 \
                && autoreconf -fi \
                && ./configure \
                && make \
                && make install

# shairport-sync
WORKDIR       /build/shairport-sync
# Do we really want libsoxr
RUN           autoreconf -fi \
                && ./configure \
                  --with-alsa \
                  --with-tinysvcmdns \
                  --with-ssl=openssl \
                  --with-soxr \
                  --with-piddir=/data/pid \
                  --with-apple-alac \
                  --sysconfdir=/config \
                && make \
                && make install

COPY          --from=builder-healthcheck /dist/boot/bin           /dist/boot/bin
RUN           cp /usr/local/bin/shairport-sync /dist/boot/bin
RUN           chmod 555 /dist/boot/bin/*

# TODO move the other libraries in as well to avoid installation in the runtime image
WORKDIR       /dist/boot/lib/
RUN           cp /usr/lib/"$(gcc -dumpmachine)"/libasound.so.2  .
RUN           cp /usr/local/lib/libalac.so.0 /dist/boot/lib/

#######################
# Running image
#######################
# hadolint ignore=DL3006
FROM          $RUNTIME_BASE

USER          root

ARG           DEBIAN_FRONTEND="noninteractive"
ENV           TERM="xterm" LANG="C.UTF-8" LC_ALL="C.UTF-8"
RUN           apt-get update -qq \
              && apt-get install -qq --no-install-recommends \
                libpopt0=1.16-12 \
                libsoxr0=0.1.2-3 \
                libconfig9=1.5-0.4 \
                libssl1.1=1.1.1d-0+deb10u2 \
              && apt-get -qq autoremove       \
              && apt-get -qq clean            \
              && rm -rf /var/lib/apt/lists/*  \
              && rm -rf /tmp/*                \
              && rm -rf /var/tmp/*

USER          dubo-dubon-duponey

COPY          --from=builder --chown=$BUILD_UID:root /dist .

ENV           NAME=TotaleCroquette

ENV           HEALTHCHECK_URL=rtsp://127.0.0.1:5000

EXPOSE        5000/tcp
EXPOSE        6001-6011/udp

HEALTHCHECK --interval=30s --timeout=30s --start-period=10s --retries=1 CMD rtsp-health || exit 1
