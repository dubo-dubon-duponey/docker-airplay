ARG           FROM_REGISTRY=ghcr.io/dubo-dubon-duponey

ARG           FROM_IMAGE_FETCHER=base:golang-bullseye-2021-08-01@sha256:820caa12223eb2f1329736bcba8f1ac96a8ab7db37370cbe517dbd1d9f6ca606
ARG           FROM_IMAGE_BUILDER=base:builder-bullseye-2021-08-01@sha256:f492d8441ddd82cad64889d44fa67cdf3f058ca44ab896de436575045a59604c
ARG           FROM_IMAGE_AUDITOR=base:auditor-bullseye-2021-08-01@sha256:0f9017945c84b48c5e9906f3325409ab446964a9e97c65a1e1820f2dd3ff1b2c
ARG           FROM_IMAGE_TOOLS=tools:linux-bullseye-2021-08-01@sha256:cec37383d167e274e3140f2b5db8cb80d0fb406538372f0c23ba09d97ee0b2a3
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

FROM          --platform=$BUILDPLATFORM $FROM_REGISTRY/$FROM_IMAGE_BUILDER                                              AS fetcher-goplay

ARG           GIT_REPO=github.com/openairplay/goplay2
ARG           GIT_VERSION=dcbcdf3
ARG           GIT_COMMIT=dcbcdf3f7640310eda10ea1048d0ed85ff899857

ENV           WITH_BUILD_SOURCE="."
ENV           WITH_BUILD_OUTPUT="goplay2"
ENV           CGO_ENABLED=1
ENV           ENABLE_STATIC=1

RUN           git clone --recurse-submodules git://"$GIT_REPO" .; git checkout "$GIT_COMMIT"
RUN           --mount=type=secret,id=CA \
              --mount=type=secret,id=NETRC \
              [[ "${GOFLAGS:-}" == *-mod=vendor* ]] || go mod vendor

FROM          --platform=$BUILDPLATFORM $FROM_REGISTRY/$FROM_IMAGE_FETCHER                                              AS fetcher-fdk

ARG           GIT_REPO=github.com/mstorsjo/fdk-aac
ARG           GIT_VERSION=v2.0.2
ARG           GIT_COMMIT=801f67f671929311e0c9952c5f92d6e147c7b003

RUN           git clone --recurse-submodules git://"$GIT_REPO" .; git checkout "$GIT_COMMIT"

#######################
# Building image
#######################
FROM          --platform=$BUILDPLATFORM $FROM_REGISTRY/$FROM_IMAGE_BUILDER                                              AS builder-fdk

ARG           TARGETARCH
ARG           TARGETVARIANT

COPY          --from=fetcher-fdk /source /source

# hadolint ignore=SC2046
RUN           eval "$(dpkg-architecture -A "$(echo "$TARGETARCH$TARGETVARIANT" | sed -e "s/^armv6$/armel/" -e "s/^armv7$/armhf/" -e "s/^ppc64le$/ppc64el/" -e "s/^386$/i386/")")"; \
              export PKG_CONFIG="${DEB_TARGET_GNU_TYPE}-pkg-config"; \
              export CC="${DEB_TARGET_GNU_TYPE}-gcc"; \
              export CXX="${DEB_TARGET_GNU_TYPE}-g++"; \
              mkdir -p m4; \
              autoreconf -fi; \
              ./configure \
                --prefix=/dist/boot/ \
                --host="$DEB_TARGET_GNU_TYPE" \
                --enable-static \
                --disable-shared; \
              make; \
              make install

FROM          --platform=$BUILDPLATFORM fetcher-goplay                                                                  AS builder-goplay

ARG           TARGETOS
ARG           TARGETARCH
ARG           TARGETVARIANT
ENV           GOOS=$TARGETOS
ENV           GOARCH=$TARGETARCH

ENV           CGO_CFLAGS="${CFLAGS:-} ${ENABLE_PIE:+-fPIE}"
ENV           GOFLAGS="-trimpath ${ENABLE_PIE:+-buildmode=pie} ${GOFLAGS:-}"

COPY          --from=builder-fdk /dist/boot /dist/boot
#                libfdk-aac2:"$DEB_TARGET_ARCH"=2.0.1-1 \
#                libfdk-aac-dev:"$DEB_TARGET_ARCH"=2.0.1-1 \

# Configure
# XXX this one may be ported in base
ARG           PKG_CONFIG_PATH="$PKG_CONFIG_PATH":/dist/boot/lib/pkgconfig

# XXX forcing non-free here is kinda lame - prefered option would be to build libfdk-aac from scratch, statically
# hadolint ignore=DL3009
RUN           --mount=type=secret,uid=100,id=CA \
              --mount=type=secret,uid=100,id=CERTIFICATE \
              --mount=type=secret,uid=100,id=KEY \
              --mount=type=secret,uid=100,id=GPG.gpg \
              --mount=type=secret,id=NETRC \
              --mount=type=secret,id=APT_SOURCES \
              --mount=type=secret,id=APT_CONFIG \
              eval "$(dpkg-architecture -A "$(echo "$TARGETARCH$TARGETVARIANT" | sed -e "s/^armv6$/armel/" -e "s/^armv7$/armhf/" -e "s/^ppc64le$/ppc64el/" -e "s/^386$/i386/")")"; \
              sed -Ei 's/main$/main non-free/g' /etc/apt/sources.list; \
              apt-get update; \
              apt-get install -qq --no-install-recommends \
                portaudio19-dev:"$DEB_TARGET_ARCH"=19.6.0-1.1

# Important cases being handled:
# - cannot compile statically with PIE but on amd64 and arm64
# - cannot compile fully statically with NETCGO
RUN           export GOARM="$(printf "%s" "$TARGETVARIANT" | tr -d v)"; \
              [ "${CGO_ENABLED:-}" != 1 ] || { \
                eval "$(dpkg-architecture -A "$(echo "$TARGETARCH$TARGETVARIANT" | sed -e "s/^armv6$/armel/" -e "s/^armv7$/armhf/" -e "s/^ppc64le$/ppc64el/" -e "s/^386$/i386/")")"; \
                export PKG_CONFIG="${DEB_TARGET_GNU_TYPE}-pkg-config"; \
                export AR="${DEB_TARGET_GNU_TYPE}-ar"; \
                export CC="${DEB_TARGET_GNU_TYPE}-gcc"; \
                export CXX="${DEB_TARGET_GNU_TYPE}-g++"; \
                [ ! "${ENABLE_STATIC:-}" ] || { \
                  [ ! "${WITH_CGO_NET:-}" ] || { \
                    ENABLE_STATIC=; \
                    LDFLAGS="${LDFLAGS:-} -static-libgcc -static-libstdc++"; \
                  }; \
                  [ "$GOARCH" == "amd64" ] || [ "$GOARCH" == "arm64" ] || [ "${ENABLE_PIE:-}" != true ] || ENABLE_STATIC=; \
                }; \
                WITH_LDFLAGS="${WITH_LDFLAGS:-} -linkmode=external -extld="$CC" -extldflags \"${LDFLAGS:-} ${ENABLE_STATIC:+-static}${ENABLE_PIE:+-pie}\""; \
                WITH_TAGS="${WITH_TAGS:-} cgo ${ENABLE_STATIC:+static static_build}"; \
              }; \
              go build -ldflags "-s -w -v ${WITH_LDFLAGS:-}" -tags "${WITH_TAGS:-} net${WITH_CGO_NET:+c}go osusergo" -o /dist/boot/bin/"$WITH_BUILD_OUTPUT" "$WITH_BUILD_SOURCE";

#RUN           eval "$(dpkg-architecture -A "$(echo "$TARGETARCH$TARGETVARIANT" | sed -e "s/^armv6$/armel/" -e "s/^armv7$/armhf/" -e "s/^ppc64le$/ppc64el/" -e "s/^386$/i386/")")"; \
#              mkdir -p /dist/boot/lib; \
#              cp /usr/lib/"$DEB_TARGET_MULTIARCH"/libfdk-aac.so.2   /dist/boot/lib

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

COPY          --from=builder-shairport  /dist/boot            /dist/boot
COPY          --from=builder-shairport  /usr/share/alsa       /dist/usr/share/alsa
COPY          --from=builder-tools      /boot/bin/rtsp-health /dist/boot/bin

COPY          --from=builder-goplay     /dist/boot            /dist/boot

RUN           setcap 'cap_net_bind_service+ep' /dist/boot/bin/goplay2

RUN           chmod 555 /dist/boot/bin/*; \
              epoch="$(date --date "$BUILD_CREATED" +%s)"; \
              find /dist/boot -newermt "@$epoch" -exec touch --no-dereference --date="@$epoch" '{}' +;

RUN           [ "$TARGETARCH" != "amd64" ] || export STACK_CLASH=true; \
              RUNNING=true \
              BIND_NOW=true \
              PIE=true \
              FORTIFIED=true \
              STACK_PROTECTED=true \
              RO_RELOCATIONS=true \
              NO_SYSTEM_LINK=true \
                dubo-check validate /dist/boot/bin/shairport-sync

# XXX should have RO_RELOCATIONS=true ?
RUN           RUNNING=true \
              STATIC=true \
                dubo-check validate /dist/boot/bin/rtsp-health

RUN           RO_RELOCATIONS=true \
              STATIC=true \
                dubo-check validate /dist/boot/bin/goplay2

#######################
# Running image
#######################
FROM          $FROM_REGISTRY/$FROM_IMAGE_RUNTIME

USER          root

# Install dependencies and tools
RUN           --mount=type=secret,uid=100,id=CA \
              --mount=type=secret,uid=100,id=CERTIFICATE \
              --mount=type=secret,uid=100,id=KEY \
              --mount=type=secret,uid=100,id=GPG.gpg \
              --mount=type=secret,id=NETRC \
              --mount=type=secret,id=APT_SOURCES \
              --mount=type=secret,id=APT_CONFIG \
              apt-get update -qq && \
              apt-get install -qq --no-install-recommends \
                dbus=1.12.20-2 \
                pulseaudio=14.2-2 && \
              apt-get -qq autoremove      && \
              apt-get -qq clean           && \
              rm -rf /var/lib/apt/lists/* && \
              rm -rf /tmp/*               && \
              rm -rf /var/tmp/*

RUN           dbus-uuidgen --ensure \
              && mkdir -p /run/dbus \
              && chown "$BUILD_UID":root /run/dbus \
              && chmod 775 /run/dbus

USER          dubo-dubon-duponey

COPY          --from=assembly --chown=$BUILD_UID:root /dist /

# (alsa|stdout|pipe)
ENV           OUTPUT=alsa
# Set this to 2 to use goplay instead of shairport-sync
ENV           AIRPLAY_VERSION=1

# Name is used as a short description for the service
ENV           MDNS_NAME="Totales Croquetas"
ENV           LOG_LEVEL=warn
ENV           PORT=5000

ENV           HEALTHCHECK_URL=rtsp://127.0.0.1:$PORT

EXPOSE        $PORT/tcp
EXPOSE        6001-6011/udp

VOLUME        /tmp

HEALTHCHECK --interval=120s --timeout=30s --start-period=10s --retries=1 CMD rtsp-health || exit 1
