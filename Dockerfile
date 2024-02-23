ARG           FROM_REGISTRY=docker.io/dubodubonduponey

ARG           FROM_IMAGE_FETCHER=base:golang-bookworm-2023-09-05
ARG           FROM_IMAGE_BUILDER=base:builder-bookworm-2023-09-05
ARG           FROM_IMAGE_AUDITOR=base:auditor-bookworm-2023-09-05
ARG           FROM_IMAGE_TOOLS=tools:linux-bookworm-2023-09-05
ARG           FROM_IMAGE_RUNTIME=base:runtime-bookworm-2023-09-05

FROM          $FROM_REGISTRY/$FROM_IMAGE_TOOLS                                                                          AS builder-tools

#######################
# Fetching
#######################
FROM          --platform=$BUILDPLATFORM $FROM_REGISTRY/$FROM_IMAGE_FETCHER                                              AS fetcher-alac

ARG           GIT_REPO=github.com/mikebrady/alac
ARG           GIT_VERSION=96dd59d
ARG           GIT_COMMIT=96dd59d17b776a7dc94ed9b2c2b4a37177feb3c4

RUN           git clone --recurse-submodules https://"$GIT_REPO" .; git checkout "$GIT_COMMIT"

FROM          --platform=$BUILDPLATFORM $FROM_REGISTRY/$FROM_IMAGE_FETCHER                                              AS fetcher-nqptp

ARG           GIT_REPO=github.com/mikebrady/nqptp
ARG           GIT_VERSION=v1.2.4
ARG           GIT_COMMIT=591f425d9da69f1c4e09f3ad09611b758937b3e5

RUN           git clone --recurse-submodules https://"$GIT_REPO" .; git checkout "$GIT_COMMIT"

FROM          --platform=$BUILDPLATFORM $FROM_REGISTRY/$FROM_IMAGE_FETCHER                                              AS fetcher-shairport

ARG           GIT_REPO=github.com/mikebrady/shairport-sync
ARG           GIT_VERSION=4.3.2
ARG           GIT_COMMIT=2ed5d998fb52040174af200f96f868622f87453a

RUN           git clone --recurse-submodules https://"$GIT_REPO" .; git checkout "$GIT_COMMIT"


#######################
# Building
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

FROM          --platform=$BUILDPLATFORM $FROM_REGISTRY/$FROM_IMAGE_BUILDER                                              AS builder-nqptp

ARG           TARGETARCH
ARG           TARGETVARIANT

COPY          --from=fetcher-nqptp /source /source

# hadolint ignore=SC2046
RUN           eval "$(dpkg-architecture -A "$(echo "$TARGETARCH$TARGETVARIANT" | sed -e "s/^armv6$/armel/" -e "s/^armv7$/armhf/" -e "s/^ppc64le$/ppc64el/" -e "s/^386$/i386/")")"; \
              export PKG_CONFIG="${DEB_TARGET_GNU_TYPE}-pkg-config"; \
              export CC="${DEB_TARGET_GNU_TYPE}-gcc"; \
              export CXX="${DEB_TARGET_GNU_TYPE}-g++"; \
              autoreconf -fi; \
              ./configure \
                --prefix=/dist/boot/ \
                --host="$DEB_TARGET_GNU_TYPE"; \
              make; \
              make install

FROM          --platform=$BUILDPLATFORM $FROM_REGISTRY/$FROM_IMAGE_BUILDER                                              AS builder-shairport

ARG           TARGETARCH
ARG           TARGETVARIANT

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
                libavutil-dev:"$DEB_TARGET_ARCH" \
                libavcodec-dev:"$DEB_TARGET_ARCH" \
                libavformat-dev:"$DEB_TARGET_ARCH" \
                uuid-dev:"$DEB_TARGET_ARCH" \
                libgcrypt20-dev:"$DEB_TARGET_ARCH" \
                libsodium-dev:"$DEB_TARGET_ARCH" \
                libplist-dev:"$DEB_TARGET_ARCH" \
                libmosquitto-dev:"$DEB_TARGET_ARCH" \
                libasound2-dev:"$DEB_TARGET_ARCH"=1.2.8-1+b1 \
                libconfig-dev:"$DEB_TARGET_ARCH"=1.5-0.4 \
                libpopt-dev:"$DEB_TARGET_ARCH"=1.19+dfsg-1 \
                xxd:"$DEB_TARGET_ARCH"; \
              apt-get install -qq --no-install-recommends \
                libmbedtls-dev:"$DEB_TARGET_ARCH" \
                libsoxr-dev:"$DEB_TARGET_ARCH"=0.1.3-4 \
                libsndfile1-dev:"$DEB_TARGET_ARCH"; \
              apt-get install -qq --no-install-recommends \
                libssl-dev:"$DEB_TARGET_ARCH"=3.0.9-1 \
                libavahi-client-dev:"$DEB_TARGET_ARCH"=0.8-10 \
                avahi-daemon:"$DEB_TARGET_ARCH"=0.8-10

# Bring in runtime dependencies
# avutil would be dragging in: libavutil56 libbsd0 libdrm-common libdrm2 libmd0 libva-drm2 libva-x11-2 libva2 libvdpau1 libx11-6 libx11-data libxau6 libxcb1 libxdmcp6 libxext6 libxfixes3 ocl-icd-libopencl1
RUN           eval "$(dpkg-architecture -A "$(echo "$TARGETARCH$TARGETVARIANT" | sed -e "s/^armv6$/armel/" -e "s/^armv7$/armhf/" -e "s/^ppc64le$/ppc64el/" -e "s/^386$/i386/")")"; \
              mkdir -p /dist/boot/lib; \
              cp /usr/lib/"$DEB_TARGET_MULTIARCH"/libgcrypt.so.20     /dist/boot/lib; \
              cp /usr/lib/"$DEB_TARGET_MULTIARCH"/libsodium.so.23     /dist/boot/lib; \
              cp /usr/lib/"$DEB_TARGET_MULTIARCH"/libplist-2.0.so.3   /dist/boot/lib; \
              cp /usr/lib/"$DEB_TARGET_MULTIARCH"/libmosquitto.so.1   /dist/boot/lib; \
              cp /usr/lib/"$DEB_TARGET_MULTIARCH"/libasound.so.2      /dist/boot/lib; \
              cp /usr/lib/"$DEB_TARGET_MULTIARCH"/libcrypto.so.3      /dist/boot/lib; \
              cp /usr/lib/"$DEB_TARGET_MULTIARCH"/libconfig.so.9      /dist/boot/lib; \
              cp /usr/lib/"$DEB_TARGET_MULTIARCH"/libpopt.so.0        /dist/boot/lib; \
              cp /usr/lib/"$DEB_TARGET_MULTIARCH"/libuuid.so.1        /dist/boot/lib; \
              cp /usr/lib/"$DEB_TARGET_MULTIARCH"/libmbedcrypto.so.7  /dist/boot/lib; \
              cp /usr/lib/"$DEB_TARGET_MULTIARCH"/libsoxr.so.0        /dist/boot/lib; \
              cp /usr/lib/"$DEB_TARGET_MULTIARCH"/libsndfile.so.1     /dist/boot/lib; \
              cp /usr/lib/"$DEB_TARGET_MULTIARCH"/libavahi-client.so.3 /dist/boot/lib

# libav are pulling a large number of dependencies... right now, just install them in the runtime

# Get the rest of the stuff
COPY          --from=builder-alac /dist/boot /dist/boot
COPY          --from=builder-nqptp /dist/boot /dist/boot

# Configure
# XXX this one may be ported in base
ARG           PKG_CONFIG_PATH="$PKG_CONFIG_PATH":/dist/boot/lib/pkgconfig
ARG           CPATH=/dist/boot/include

# Get our source
COPY          --from=fetcher-shairport /source /source

# Build
#              export CFLAGS=-static; \
#              export LDFLAGS=-static; \
#              export CPPFLAGS=-static; \
# LD_LIBRARY_PATH
RUN           eval "$(dpkg-architecture -A "$(echo "$TARGETARCH$TARGETVARIANT" | sed -e "s/^armv6$/armel/" -e "s/^armv7$/armhf/" -e "s/^ppc64le$/ppc64el/" -e "s/^386$/i386/")")"; \
              export PKG_CONFIG="${DEB_TARGET_GNU_TYPE}-pkg-config"; \
              export CC="${DEB_TARGET_GNU_TYPE}-gcc"; \
              export CXX="${DEB_TARGET_GNU_TYPE}-g++"; \
              autoreconf -fi; \
              ./configure \
                --host="$DEB_TARGET_GNU_TYPE" \
                --prefix=/dist/boot \
                --with-airplay-2 \
                --with-alsa \
                --with-stdout \
                --with-pipe \
                --with-apple-alac \
                --with-metadata \
                --with-mqtt-client \
                --with-piddir=/tmp \
                --with-ssl=openssl \
                --with-avahi \
                --with-os=linux \
                --with-configfiles	\
                --without-soxr \
                --without-convolution \
                --sysconfdir=/config \
                --without-sndio \
                --without-pa \
                --without-pw \
                --without-ao \
                --without-jack \
                --without-soundio \
                --without-dbus-interface \
                --without-dbus-test-client \
                --without-mpris-interface \
                --without-mpris-test-client \
                --without-libdaemon \
                --without-systemd \
                --without-systemdsystemunitdir \
                --without-systemv \
                --without-freebsd-service \
                --without-sygwin-service \
                --without-tinysvcmdns; \
              make; \
              make install
#                --with-ssl=mbedtls \

# Cleanup
RUN           rm /dist/boot/lib/libalac.a
RUN           rm /dist/boot/lib/libalac.la

# Apparently pulled in by avahi or ffmpeg, so, for the time being, no need to keep these
RUN           rm /dist/boot/lib/libuuid.so.1
RUN           rm /dist/boot/lib/libsodium.so.23
RUN           rm /dist/boot/lib/libgcrypt.so.20
RUN           rm /dist/boot/lib/libcrypto.so.3
RUN           rm /dist/boot/lib/libsoxr.so.0

# Not usable right now
RUN           rm /dist/boot/lib/libmbedcrypto.so.7

RUN           rm -Rf /dist/boot/include
RUN           rm -Rf /dist/boot/share

#######################
# Builder assembly
#######################
FROM          --platform=$BUILDPLATFORM $FROM_REGISTRY/$FROM_IMAGE_AUDITOR                                              AS assembly

ARG           TARGETARCH

COPY          --from=builder-shairport  /dist/boot            /dist/boot
COPY          --from=builder-shairport  /usr/share/alsa       /dist/usr/share/alsa
COPY          --from=builder-tools      /boot/bin/rtsp-health /dist/boot/bin

RUN           setcap 'cap_net_bind_service+ep'                /dist/boot/bin/nqptp

# hadolint ignore=SC2016
RUN           patchelf --set-rpath '$ORIGIN/../lib'           /dist/boot/bin/shairport-sync

RUN           RUNNING=true \
              STATIC=true \
                dubo-check validate /dist/boot/bin/rtsp-health

# XXX rpath may be borked
# RUN           [ "$TARGETARCH" != "amd64" ] || export STACK_CLASH=true; \
RUN           BIND_NOW=true \
              PIE=true \
              FORTIFIED=true \
              STACK_PROTECTED=true \
              RO_RELOCATIONS=true \
                dubo-check validate /dist/boot/bin/shairport-sync; \
                dubo-check validate /dist/boot/bin/nqptp

RUN           chmod 555 /dist/boot/bin/*; \
              epoch="$(date --date "$BUILD_CREATED" +%s)"; \
              find /dist/boot -newermt "@$epoch" -exec touch --no-dereference --date="@$epoch" '{}' +;

#######################
# Running image
#######################
FROM          $FROM_REGISTRY/$FROM_IMAGE_RUNTIME

COPY          --from=assembly --chown=$BUILD_UID:root /dist /

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
                libavutil57 \
                libavcodec59 \
                libavformat59 \
                avahi-daemon \
              && apt-get -qq autoremove       \
              && apt-get -qq clean            \
              && rm -rf /var/lib/apt/lists/*  \
              && rm -rf /tmp/*                \
              && rm -rf /var/tmp/*

RUN           mkdir -p /run/avahi-daemon; chown avahi:avahi /run/avahi-daemon; chmod 777 /run/avahi-daemon

USER          dubo-dubon-duponey

# Name is used as a short description for the service
ENV           MOD_MDNS_NAME="Speakeasy"

ENV           LOG_LEVEL="warn"

# Will default to "default"
ENV           DEVICE=""
# (alsa|stdout|pipe)
ENV           OUTPUT=alsa

ENV           ADVANCED_AIRPLAY_PORT=7000
ENV           HEALTHCHECK_URL=rtsp://127.0.0.1:$ADVANCED_AIRPLAY_PORT

EXPOSE        $ADVANCED_AIRPLAY_PORT/tcp
# nqptp ports
EXPOSE        319
EXPOSE        320

# Used by dbus
VOLUME        /tmp
# Avahi is special... ;/
VOLUME        /run/avahi-daemon

HEALTHCHECK   --interval=120s --timeout=30s --start-period=10s --retries=1 CMD rtsp-health || exit 1
