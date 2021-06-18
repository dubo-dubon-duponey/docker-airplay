ARG           FROM_IMAGE_BUILDER=ghcr.io/dubo-dubon-duponey/base:builder-bullseye-2021-06-01@sha256:addbd9b89d8973df985d2d95e22383961ba7b9c04580ac6a7f406a3a9ec4731e
ARG           FROM_IMAGE_RUNTIME=ghcr.io/dubo-dubon-duponey/base:runtime-bullseye-2021-06-01@sha256:a2b1b2f69ed376bd6ffc29e2d240e8b9d332e78589adafadb84c73b778e6bc77

#######################
# Extra builder for healthchecker
#######################
FROM          --platform=$BUILDPLATFORM $FROM_IMAGE_BUILDER                                                             AS builder-healthcheck

ARG           GIT_REPO=github.com/dubo-dubon-duponey/healthcheckers
ARG           GIT_VERSION=51ebf8c
ARG           GIT_COMMIT=51ebf8ca3d255e0c846307bf72740f731e6210c3
ARG           GO_BUILD_SOURCE=./cmd/rtsp
ARG           GO_BUILD_OUTPUT=rtsp-health
ARG           GO_LD_FLAGS="-s -w"
ARG           GO_TAGS="netgo osusergo"

WORKDIR       $GOPATH/src/$GIT_REPO
RUN           git clone --recurse-submodules git://"$GIT_REPO" . && git checkout "$GIT_COMMIT"
ARG           GOOS="$TARGETOS"
ARG           GOARCH="$TARGETARCH"

# hadolint ignore=SC2046
RUN           env GOARM="$(printf "%s" "$TARGETVARIANT" | tr -d v)" go build -trimpath $(if [ "$CGO_ENABLED" = 1 ]; then printf "%s" "-buildmode pie"; fi) \
                -ldflags "$GO_LD_FLAGS" -tags "$GO_TAGS" -o /dist/boot/bin/"$GO_BUILD_OUTPUT" "$GO_BUILD_SOURCE"

#######################
# Building image
#######################
# XXX compile all that statically and x-pile
FROM          $FROM_IMAGE_BUILDER                                                                                       AS builder-alac

# ALAC from apple: Feb 2019
ARG           GIT_REPO=github.com/mikebrady/alac
ARG           GIT_VERSION=5d6d836
ARG           GIT_COMMIT=5d6d836ee5b025a5e538cfa62c88bc5bced506ed

WORKDIR       $GOPATH/src/$GIT_REPO
RUN           git clone --recurse-submodules git://"$GIT_REPO" . && git checkout "$GIT_COMMIT"

RUN           mkdir -p m4 \
                && autoreconf -fi \
                && ./configure \
                && make \
                && make install

RUN           mkdir -p /dist/boot/lib; cp /usr/local/lib/libalac.so.0 /dist/boot/lib

# TODO move the other libraries in as well to avoid installation in the runtime image
# XXX libasound-data does install more stuff than just the lib
# RUN           cp /usr/lib/"$(gcc -dumpmachine)"/libasound.so.2  .

#######################
# Building image
#######################
FROM          $FROM_IMAGE_BUILDER                                                                                       AS builder-shairport

# shairport-sync: v3.3.8
ARG           GIT_REPO=github.com/mikebrady/shairport-sync
ARG           GIT_VERSION=c19f697
ARG           GIT_COMMIT=c19f697be2b6761616876787064d6b067cf87089

WORKDIR       $GOPATH/src/$GIT_REPO
RUN           git clone --recurse-submodules git://"$GIT_REPO" . && git checkout "$GIT_COMMIT"

RUN           --mount=type=secret,mode=0444,id=CA,dst=/etc/ssl/certs/ca-certificates.crt \
              --mount=type=secret,id=CERTIFICATE \
              --mount=type=secret,id=KEY \
              --mount=type=secret,id=PASSPHRASE \
              --mount=type=secret,mode=0444,id=GPG.gpg \
              --mount=type=secret,id=NETRC \
              --mount=type=secret,id=APT_SOURCES \
              --mount=type=secret,id=APT_OPTIONS,dst=/etc/apt/apt.conf.d/dbdbdp.conf \
              apt-get update -qq && \
              apt-get install -qq --no-install-recommends \
                libasound2-dev=1.2.4-1.1 \
                libpopt-dev=1.18-2 \
                libsoxr-dev=0.1.3-4 \
                libconfig-dev=1.5-0.4 \
                libssl-dev=1.1.1k-1 \
                libcrypto++-dev=8.4.0-1

# XXX Do we really want libsoxr?
# stdout & pipe blindly added to possibly benefit snapcasters
# if feasible, get rid of the mdns stack here
RUN           autoreconf -fi \
                && ./configure \
                  --with-alsa \
                  --with-pipe \
                  --with-stdout \
                  --with-tinysvcmdns \
                  --with-ssl=openssl \
                  --with-soxr \
                  --with-piddir=/data/pid \
                  --with-apple-alac \
                  --sysconfdir=/config \
                && make \
                && make install

RUN           mkdir -p /dist/boot/bin; cp /usr/local/bin/shairport-sync /dist/boot/bin


#######################
# Building image
#######################
FROM          $FROM_IMAGE_BUILDER                                                                                       AS builder

COPY          --from=builder-healthcheck /dist/boot/bin /dist/boot/bin
COPY          --from=builder-alac /dist/boot /dist/boot
COPY          --from=builder-shairport /dist/boot/bin /dist/boot/bin

RUN           chmod 555 /dist/boot/bin/*; \
              epoch="$(date --date "$BUILD_CREATED" +%s)"; \
              find /dist/boot/bin -newermt "@$epoch" -exec touch --no-dereference --date="@$epoch" '{}' +;

#######################
# Running image
#######################
FROM          $FROM_IMAGE_RUNTIME

USER          root

RUN           apt-get update -qq \
              && apt-get install -qq --no-install-recommends \
                libasound2=1.2.4-1.1 \
                libpopt0=1.18-2 \
                libsoxr0=0.1.3-4 \
                libconfig9=1.5-0.4 \
                libssl1.1=1.1.1k-1 \
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
