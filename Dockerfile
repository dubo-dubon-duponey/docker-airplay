ARG           FROM_REGISTRY=ghcr.io/dubo-dubon-duponey

ARG           FROM_IMAGE_FETCHER=base:golang-bullseye-2021-08-01@sha256:820caa12223eb2f1329736bcba8f1ac96a8ab7db37370cbe517dbd1d9f6ca606
ARG           FROM_IMAGE_BUILDER=base:builder-bullseye-2021-08-01@sha256:f492d8441ddd82cad64889d44fa67cdf3f058ca44ab896de436575045a59604c
ARG           FROM_IMAGE_TOOLS=tools:linux-bullseye-2021-08-01@sha256:87ec12fe94a58ccc95610ee826f79b6e57bcfd91aaeb4b716b0548ab7b2408a7
ARG           FROM_IMAGE_AUDITOR=base:auditor-bullseye-2021-08-01@sha256:701da0f301d57910c28dadae2f03ca4d788cadd2ce192b6ec7aae80232081fe9
ARG           FROM_IMAGE_RUNTIME=base:runtime-bullseye-2021-08-01@sha256:edc80b2c8fd94647f793cbcb7125c87e8db2424f16b9fd0b8e173af850932b48

FROM          $FROM_REGISTRY/$FROM_IMAGE_TOOLS                                                                          AS builder-tools

#######################
# Fetchers
#######################
FROM          --platform=$BUILDPLATFORM $FROM_REGISTRY/$FROM_IMAGE_FETCHER                                              AS fetcher-alac

ARG           GIT_REPO=github.com/mikebrady/alac
ARG           GIT_VERSION=5d6d836
ARG           GIT_COMMIT=5d6d836ee5b025a5e538cfa62c88bc5bced506ed

RUN           git clone --recurse-submodules git://"$GIT_REPO" .; git checkout "$GIT_COMMIT"

FROM          --platform=$BUILDPLATFORM $FROM_REGISTRY/$FROM_IMAGE_FETCHER                                              AS fetcher-shairport

ARG           GIT_REPO=github.com/mikebrady/shairport-sync
ARG           GIT_VERSION=v3.3.8
ARG           GIT_COMMIT=f496ca664ef133d428fc80fa3f718244a3916a64

RUN           git clone --recurse-submodules git://"$GIT_REPO" .; git checkout "$GIT_COMMIT"

#######################
# Building image
#######################
FROM          --platform=$BUILDPLATFORM $FROM_REGISTRY/$FROM_IMAGE_BUILDER                                              AS builder-alac

ARG           TARGETARCH
ARG           TARGETVARIANT

COPY          --from=fetcher-alac /source /source

# hadolint ignore=SC2046
RUN           eval "$(dpkg-architecture -A "$(echo "$TARGETARCH$TARGETVARIANT" | sed -e "s/^armv6$/armel/" -e "s/^armv7$/armhf/" -e "s/^ppc64le$/ppc64el/" -e "s/^386$/i386/")")"; \
              export PKG_CONFIG="${DEB_TARGET_GNU_TYPE}-pkg-config"; \
              export CC="${DEB_TARGET_GNU_TYPE}-gcc"; \
              export CXX="${DEB_TARGET_GNU_TYPE}-g++"; \
              mkdir -p m4; \
              autoreconf -fi; \
              ./configure \
                --prefix=/dist/boot/ \
                --host="$DEB_TARGET_GNU_TYPE"; \
              make; \
              make install

FROM          --platform=$BUILDPLATFORM $FROM_REGISTRY/$FROM_IMAGE_BUILDER                                              AS builder-shairport

ARG           TARGETARCH
ARG           TARGETVARIANT

# Get our additional dependencies
# hadolint ignore=DL3009
RUN           --mount=type=secret,uid=100,id=CA \
              --mount=type=secret,uid=100,id=CERTIFICATE \
              --mount=type=secret,uid=100,id=KEY \
              --mount=type=secret,uid=100,id=GPG.gpg \
              --mount=type=secret,id=NETRC \
              --mount=type=secret,id=APT_SOURCES \
              --mount=type=secret,id=APT_CONFIG \
              eval "$(dpkg-architecture -A "$(echo "$TARGETARCH$TARGETVARIANT" | sed -e "s/^armv6$/armel/" -e "s/^armv7$/armhf/" -e "s/^ppc64le$/ppc64el/" -e "s/^386$/i386/")")"; \
              apt-get update -qq; \
              apt-get install -qq --no-install-recommends \
                libpopt-dev:"$DEB_TARGET_ARCH"=1.18-2 \
                libconfig-dev:"$DEB_TARGET_ARCH"=1.5-0.4 \
                libasound2-dev:"$DEB_TARGET_ARCH"=1.2.4-1.1 \
                libsoxr-dev:"$DEB_TARGET_ARCH"=0.1.3-4 \
                libssl-dev:"$DEB_TARGET_ARCH"=1.1.1k-1 \
                libcrypto++-dev:"$DEB_TARGET_ARCH"=8.4.0-1

# Bring in runtime dependencies
RUN           eval "$(dpkg-architecture -A "$(echo "$TARGETARCH$TARGETVARIANT" | sed -e "s/^armv6$/armel/" -e "s/^armv7$/armhf/" -e "s/^ppc64le$/ppc64el/" -e "s/^386$/i386/")")"; \
              mkdir -p /dist/boot/lib; \
              cp /usr/lib/"$DEB_TARGET_MULTIARCH"/libasound.so.2   /dist/boot/lib; \
              cp /usr/lib/"$DEB_TARGET_MULTIARCH"/libsoxr.so.0     /dist/boot/lib; \
              cp /usr/lib/"$DEB_TARGET_MULTIARCH"/libcrypto.so.1.1 /dist/boot/lib; \
              cp /usr/lib/"$DEB_TARGET_MULTIARCH"/libconfig.so.9   /dist/boot/lib; \
              cp /usr/lib/"$DEB_TARGET_MULTIARCH"/libpopt.so.0     /dist/boot/lib; \
              cp /usr/lib/"$DEB_TARGET_MULTIARCH"/libgomp.so.1     /dist/boot/lib; \
              cp /usr/lib/"$DEB_TARGET_MULTIARCH"/libstdc++.so.6   /dist/boot/lib

# Get the alac library we just built
COPY          --from=builder-alac /dist/boot /dist/boot

# Configure
# XXX this one may be ported in base
ARG           PKG_CONFIG_PATH="$PKG_CONFIG_PATH":/dist/boot/lib/pkgconfig
ARG           CPATH=/dist/boot/include

# Get our source
COPY          --from=fetcher-shairport /source /source

# Build
RUN           eval "$(dpkg-architecture -A "$(echo "$TARGETARCH$TARGETVARIANT" | sed -e "s/^armv6$/armel/" -e "s/^armv7$/armhf/" -e "s/^ppc64le$/ppc64el/" -e "s/^386$/i386/")")"; \
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
                --with-piddir=/tmp \
                --sysconfdir=/config \
                --with-pkg-config; \
              make; \
              make install

#######################
# Builder assembly
#######################
FROM          --platform=$BUILDPLATFORM $FROM_REGISTRY/$FROM_IMAGE_AUDITOR                                              AS assembly

ARG           TARGETARCH
ARG           TARGETVARIANT

COPY          --from=builder-shairport  /dist/boot            /dist/boot
COPY          --from=builder-shairport  /usr/share/alsa       /dist/usr/share/alsa
COPY          --from=builder-tools      /boot/bin/rtsp-health /dist/boot/bin

RUN           chmod 555 /dist/boot/bin/*; \
              epoch="$(date --date "$BUILD_CREATED" +%s)"; \
              find /dist/boot -newermt "@$epoch" -exec touch --no-dereference --date="@$epoch" '{}' +;

RUN           [ "$TARGETARCH" == "arm64" ] || [ "$TARGETARCH" == "arm" ] || export STACK_CLASH=true; \
              BIND_NOW=true \
              PIE=true \
              FORTIFIED=true \
              STACK_PROTECTED=true \
              RO_RELOCATIONS=true \
              NO_SYSTEM_LINK=true \
                dubo-check validate /dist/boot/bin/shairport-sync

RUN           STATIC=true \
                dubo-check validate /dist/boot/bin/rtsp-health

#######################
# Running image
#######################
FROM          $FROM_REGISTRY/$FROM_IMAGE_RUNTIME

COPY          --from=assembly --chown=$BUILD_UID:root /dist /

# (alsa|stdout|pipe)
ENV           OUTPUT=alsa

# Name is used as a short description for the service
ENV           MDNS_NAME="Totales Croquetas"
ENV           LOG_LEVEL=warn
ENV           PORT=5000

ENV           HEALTHCHECK_URL=rtsp://127.0.0.1:$PORT

EXPOSE        $PORT/tcp
EXPOSE        6001-6011/udp

VOLUME        /tmp

HEALTHCHECK --interval=120s --timeout=30s --start-period=10s --retries=1 CMD rtsp-health || exit 1
