##########################
# Building image
##########################
FROM        debian:buster-slim                                                                            AS builder

# Install dependencies and tools
ARG         DEBIAN_FRONTEND="noninteractive"
ENV         TERM="xterm" LANG="C.UTF-8" LC_ALL="C.UTF-8"
RUN         apt-get update                                                                                > /dev/null
RUN         apt-get install -y --no-install-recommends git=1:2.20.1-2 build-essential=12.6 autoconf=2.69-11 automake=1:1.16.1-4 libtool=2.4.6-9 pkg-config=0.29-6 > /dev/null
WORKDIR     /build

# shairport-sync: v3.3.4
ARG         SHAIRPORT_VER=b4c54fc576bb84cbb3f4ee177bf681f60fcdea9b
# Blue-alsa: v1.4.0
ARG         BLUEZ_VERSION=2725b4e8a0301aedb267d3db5850ab62586e6148
# ALAC from apple: Feb 2019
ARG         ALAC_VERSION=5d6d836ee5b025a5e538cfa62c88bc5bced506ed


RUN         git clone git://github.com/Arkq/bluez-alsa.git
RUN         git clone git://github.com/mikebrady/alac.git
RUN         git clone git://github.com/mikebrady/shairport-sync

RUN         git -C bluez-alsa     checkout  $BLUEZ_VERSION
RUN         git -C alac           checkout  $ALAC_VERSION
RUN         git -C shairport-sync checkout  $SHAIRPORT_VER

# ALAC (from apple)
WORKDIR     /build/alac
RUN         mkdir -p m4 && autoreconf -fi && ./configure && make && make install

# blue-alsa
WORKDIR     /build/bluez-alsa
RUN         apt-get install -y --no-install-recommends \
                        check=0.10.0-3+b3 \
                        libasound2-dev=1.1.8-1 \
                        libbluetooth-dev=5.50-1 \
                        libdbus-1-dev=1.12.16-1 \
                        libglib2.0-dev=2.58.3-2+deb10u1 \
                        libsbc-dev=1.4-1 \
                        libreadline-dev=7.0-5 \
                        libbsd-dev=0.9.1-2 \
                        libncurses-dev=6.1+20181013-2+deb10u1
RUN         mkdir -p m4 && autoreconf --install

WORKDIR     /build/bluez-alsa/build
RUN         ../configure --enable-test --enable-msbc --enable-ofono --enable-alac && make && make test && make install

# shairport-sync
WORKDIR     /build/shairport-sync
RUN         apt-get install -y --no-install-recommends \
                        libasound2-dev=1.1.8-1 \
                        libdaemon-dev=0.14-7 \
                        libpopt-dev=1.16-12 \
                        libsoxr-dev=0.1.2-3 \
                        libavahi-client-dev=0.7-4+b1 \
                        libconfig-dev=1.5-0.4 \
                        libssl-dev=1.1.1c-1 \
                        libcrypto++-dev=5.6.4-8
RUN         autoreconf -fi \
              && ./configure \
                --with-alsa \
                --with-pipe \
                --with-avahi \
                --with-ssl=openssl \
                --with-soxr \
                --with-metadata \
                --with-apple-alac \
                --sysconfdir=/etc \
              && make \
              && make install

#######################
# Running image
#######################
FROM        debian:buster-slim

LABEL       dockerfile.copyright="Dubo Dubon Duponey <dubo-dubon-duponey@jsboot.space>"

ARG         DEBIAN_FRONTEND="noninteractive"
ENV         TERM="xterm" LANG="C.UTF-8" LC_ALL="C.UTF-8"
RUN         apt-get update              > /dev/null && \
            apt-get install -y --no-install-recommends \
                    libbluetooth3=5.50-1 \
                    libsbc1=1.4-1 \
                    pkg-config=0.29-6 \
                    dbus=1.12.16-1 \
                    libasound2=1.1.8-1 \
                    libdaemon0=0.14-7 \
                    libpopt0=1.16-12 \
                    libsoxr0=0.1.2-3 \
                    libconfig9=1.5-0.4 \
                    libssl1.1=1.1.1c-1 \
                    avahi-daemon=0.7-4+b1 \
                    libavahi-client3=0.7-4+b1 \
                    bluetooth=5.50-1 \
                    alsa-utils=1.1.8-2          > /dev/null && \
            apt-get -y autoremove       > /dev/null && \
            apt-get -y clean            && \
            rm -rf /var/lib/apt/lists/* && \
            rm -rf /tmp/*               && \
            rm -rf /var/tmp/*

WORKDIR     /dubo-dubon-duponey
RUN         mkdir -p /var/run/dbus
COPY        avahi-daemon.conf /etc/avahi/avahi-daemon.conf
COPY        entrypoint.sh .

COPY        --from=builder /etc/shairport-sync* /etc/
COPY        --from=builder /usr/local/bin/shairport-sync /usr/local/bin/shairport-sync
COPY        --from=builder /usr/bin/bluealsa /usr/bin/bluealsa
COPY        --from=builder /usr/local/lib/libalac* /usr/local/lib/
COPY        --from=builder /usr/local/lib/pkgconfig/alac.pc /usr/local/lib/pkgconfig/alac.pc
COPY        --from=builder /usr/local/include/alac /usr/local/include/alac

# Catch-up with libalac
ENV LD_LIBRARY_PATH="$LD_LIBRARY_PATH:/usr/local/lib"
ENV NAME=TotaleCroquette
EXPOSE 554
#VOLUME "/etc/shairport-sync.conf"
#VOLUME "/etc/avahi/avahi-daemon.conf"

ENTRYPOINT ["./entrypoint.sh"]
