ARG           FROM_REGISTRY=ghcr.io/dubo-dubon-duponey

ARG           FROM_IMAGE_BUILDER=base:builder-bullseye-2021-08-01@sha256:f492d8441ddd82cad64889d44fa67cdf3f058ca44ab896de436575045a59604c
ARG           FROM_IMAGE_RUNTIME=base:runtime-bullseye-2021-08-01@sha256:edc80b2c8fd94647f793cbcb7125c87e8db2424f16b9fd0b8e173af850932b48
ARG           FROM_IMAGE_TOOLS=tools:linux-bullseye-2021-08-01@sha256:87ec12fe94a58ccc95610ee826f79b6e57bcfd91aaeb4b716b0548ab7b2408a7

FROM          $FROM_REGISTRY/$FROM_IMAGE_TOOLS                                                                          AS builder-tools

#######################
# Fetcher
#######################
FROM          --platform=$BUILDPLATFORM $FROM_REGISTRY/$FROM_IMAGE_BUILDER                                              AS fetcher-alac

ENV           GIT_REPO=github.com/mikebrady/alac
ENV           GIT_VERSION=5d6d836
ENV           GIT_COMMIT=5d6d836ee5b025a5e538cfa62c88bc5bced506ed

RUN           git clone --recurse-submodules git://"$GIT_REPO" .
RUN           git checkout "$GIT_COMMIT"

#######################
# Fetcher
#######################
FROM          --platform=$BUILDPLATFORM $FROM_REGISTRY/$FROM_IMAGE_BUILDER                                              AS fetcher-shairport

ENV           GIT_REPO=github.com/mikebrady/shairport-sync
ENV           GIT_VERSION=v3.3.8
ENV           GIT_COMMIT=f496ca664ef133d428fc80fa3f718244a3916a64

RUN           git clone --recurse-submodules git://"$GIT_REPO" .
RUN           git checkout "$GIT_COMMIT"

# hadolint ignore=DL3009
RUN           --mount=type=secret,uid=100,id=CA \
              --mount=type=secret,uid=100,id=CERTIFICATE \
              --mount=type=secret,uid=100,id=KEY \
              --mount=type=secret,uid=100,id=GPG.gpg \
              --mount=type=secret,id=NETRC \
              --mount=type=secret,id=APT_SOURCES \
              --mount=type=secret,id=APT_CONFIG \
              apt-get update -qq; \
              for architecture in armel armhf arm64 ppc64el i386 s390x amd64; do \
                apt-get install -qq --no-install-recommends \
                  libpopt-dev:"$architecture"=1.18-2 \
                  libconfig-dev:"$architecture"=1.5-0.4 \
                  libasound2-dev:"$architecture"=1.2.4-1.1 \
                  libsoxr-dev:"$architecture"=0.1.3-4 \
                  libssl-dev:"$architecture"=1.1.1k-1 \
                  libcrypto++-dev:"$architecture"=8.4.0-1; \
              done

#######################
# Building image
#######################
FROM          --platform=$BUILDPLATFORM fetcher-alac                                                                    AS builder-alac

ARG           TARGETARCH
ARG           TARGETOS
ARG           TARGETVARIANT

# hadolint ignore=SC2046
RUN           DEB_TARGET_ARCH="$(echo "$TARGETARCH$TARGETVARIANT" | sed -e "s/armv6/armel/" -e "s/armv7/armhf/" -e "s/ppc64le/ppc64el/" -e "s/386/i386/")"; \
              eval "$(dpkg-architecture -A "$DEB_TARGET_ARCH")"; \
              export PKG_CONFIG="${DEB_TARGET_GNU_TYPE}-pkg-config"; \
              export CC="${DEB_TARGET_GNU_TYPE}-gcc"; \
              export CXX="${DEB_TARGET_GNU_TYPE}-g++"; \
              mkdir -p m4 \
                && autoreconf -fi \
                && ./configure --prefix=/dist/boot/ --host="$DEB_TARGET_GNU_TYPE" \
                && make \
                && make install


FROM          --platform=$BUILDPLATFORM fetcher-shairport                                                               AS builder-shairport

ARG           TARGETARCH
ARG           TARGETOS
ARG           TARGETVARIANT

# Get the alac library over
COPY          --from=builder-alac /dist/boot /dist/boot

ENV           PKG_CONFIG_PATH="$PKG_CONFIG_PATH":/dist/boot/lib/pkgconfig
ENV           CPATH=/dist/boot/include

#  dynamic, with debug_info, not stripped
RUN           DEB_TARGET_ARCH="$(echo "$TARGETARCH$TARGETVARIANT" | sed -e "s/armv6/armel/" -e "s/armv7/armhf/" -e "s/ppc64le/ppc64el/" -e "s/386/i386/")"; \
              eval "$(dpkg-architecture -A "$DEB_TARGET_ARCH")"; \
              export PKG_CONFIG="${DEB_TARGET_GNU_TYPE}-pkg-config"; \
              export CC="${DEB_TARGET_GNU_TYPE}-gcc"; \
              export CXX="${DEB_TARGET_GNU_TYPE}-g++"; \
              autoreconf -fi; \
              ./configure \
                  --host="$DEB_TARGET_GNU_TYPE" \
                  --prefix=/dist/boot \
                  --with-alsa \
                  --with-pipe \
                  --with-stdout \
                  --with-ssl=openssl \
                  --with-soxr \
                  --with-tinysvcmdns \
                  --with-apple-alac \
                  --with-metadata \
                  --with-piddir=/tmp/pid \
                  --sysconfdir=/config \
                && make \
                && make install

#XXX $(gcc -dumpmachine)
RUN           cp /usr/lib/"$DEB_TARGET_MULTIARCH"/libsoxr.so.0  /dist/boot/lib
RUN           cp /usr/lib/"$DEB_TARGET_MULTIARCH"/libcrypto.so.1.1  /dist/boot/lib
RUN           cp /usr/lib/"$DEB_TARGET_MULTIARCH"/libconfig.so.9  /dist/boot/lib
RUN           cp /usr/lib/"$DEB_TARGET_MULTIARCH"/libpopt.so.0  /dist/boot/lib
RUN           cp /usr/lib/"$DEB_TARGET_MULTIARCH"/libgomp.so.1  /dist/boot/lib

#######################
# Builder assembly, XXX should be auditor
#######################
FROM          --platform=$BUILDPLATFORM $FROM_REGISTRY/$FROM_IMAGE_BUILDER                                              AS builder

COPY          --from=builder-shairport  /dist/boot /dist/boot

COPY          --from=builder-tools      /boot/bin/rtsp-health    /dist/boot/bin

RUN           chmod 555 /dist/boot/bin/*; \
              epoch="$(date --date "$BUILD_CREATED" +%s)"; \
              find /dist/boot -newermt "@$epoch" -exec touch --no-dereference --date="@$epoch" '{}' +;


#######################
# Running image
#######################
FROM          $FROM_REGISTRY/$FROM_IMAGE_RUNTIME

USER          root

RUN           --mount=type=secret,uid=100,id=CA \
              --mount=type=secret,uid=100,id=CERTIFICATE \
              --mount=type=secret,uid=100,id=KEY \
              --mount=type=secret,uid=100,id=GPG.gpg \
              --mount=type=secret,id=NETRC \
              --mount=type=secret,id=APT_SOURCES \
              --mount=type=secret,id=APT_CONFIG \
              apt-get update -qq \
              && apt-get install -qq --no-install-recommends \
                libasound2=1.2.4-1.1 \
              && apt-get -qq autoremove       \
              && apt-get -qq clean            \
              && rm -rf /var/lib/apt/lists/*  \
              && rm -rf /tmp/*                \
              && rm -rf /var/tmp/*

USER          dubo-dubon-duponey

COPY          --from=builder --chown=$BUILD_UID:root /dist /

ENV           NAME=TotaleCroquette

ENV           HEALTHCHECK_URL=rtsp://127.0.0.1:5000

EXPOSE        5000/tcp
EXPOSE        6001-6011/udp

HEALTHCHECK --interval=120s --timeout=30s --start-period=10s --retries=1 CMD rtsp-health || exit 1
