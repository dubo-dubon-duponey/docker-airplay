# What

A Docker image to run an Apple AirPlay Protocol receiver.

This is currently based on [shairport-sync](https://github.com/mikebrady/shairport-sync) and the [ALAC](https://github.com/mikebrady/alac) library.

This image also ships experimental support for Airplay 2 based on [goplay2](https://github.com/openairplay/goplay2).

## Image features

* multi-architecture:
  * [x] linux/amd64
  * [x] linux/arm64
  * [x] linux/arm/v7
  * [x] linux/arm/v6
* hardened:
  * [x] image runs read-only
  * [x] image runs with no cap
  * [x] process runs as a non-root user, disabled login, no shell
  * [x] shairport-sync is compiled with PIE, bind now, stack protection, fortify source and read-only relocations (additionally stack clash protection on amd64)
* lightweight
  * [x] based on our slim [Debian Bullseye](https://github.com/dubo-dubon-duponey/docker-debian)
  * [x] simple entrypoint script
  * [x] multi-stage build with no installed dependencies for the runtime image
* observable
  * [x] healthcheck
  * [x] logs to stdout
* other achitectures (386, ppc64le, s390x) probably build as well, though they are disabled by default

## Run

```bash
docker run -d --rm \
    --name "airplay" \
    --env MDNS_NAME="My Fancy Airplay Receiver" \
    --group-add audio \
    --device /dev/snd \
    --net host \
    --cap-drop ALL \
    --read-only \
    ghcr.io/dubo-dubon-duponey/airplay
```

## Notes

### Networking

You need to run this in `host` or `mac(or ip)vlan` networking (because of mDNS).

### Additional arguments

The following environment variables allow for high-level control over shairport:

* OUTPUT (alsa|pipe|stdout) controls the output
* LOG_LEVEL if set to "debug" will pass along -vvv and --statistics
* MDNS_NAME controls the announced name
* PORT controls the port to bind to

Any additional arguments passed when running the image will get fed to the `shairport-sync` binary directly.

You can get a full list of supported arguments with:

```bash
docker run --rm ghcr.io/dubo-dubon-duponey/airplay --help
```

This is specifically convenient for example to address a different Alsa card or mixer (eg: `-- -d hw:1`).

### Custom configuration file

For more advanced control over shairport-sync configuration, mount `/config/shairport-sync/main.conf`.

### Linkage

The shairport binary links dynamically against:
* libasound2
* libsoxr0
* libconfig9
* libpopt0
* libssl1.1
* libgomp.so.1
* libstdc++.so.6
* libcrypto.so.1.1

These are copied over from the build stage into the final image in /boot/lib.

Also, libalac is built in statically.

### About soxr

Soxr support is compiled in, though in our experience we had bad results on RPI using it, hence
we advise against using it on low-end hardware and do rely on "basic" instead by default.

If you want to use soxr, just pass it as an extra argument ("--stuffing=soxr") or change the config file
corresponding setting.

### About mDNS

We do not support Avahi, and instead rely on tinymdns.
Setting-up avahi in a container is doable (and we did before in this image), but it's a PITA and
requires you to setup dbus and an avahi daemon process on top of shairport, so, no thank you.

### Experimental Airplay 2 support

shairport-sync does not support it right now, and it appears unlikely to be implemented for the time being.
See https://github.com/mikebrady/shairport-sync/issues/535 for details.

If you set AIRPLAY_VERSION=2, goplay2 is used instead of shairport-sync.

Caveats:
* this is largely experimental at this point, and probably buggy
* goplay2 ignores the following: OUTPUT and PORT
* goplay2 does require NET_BIND_SERVICE to work properly
* goplay2 requires pulseaudio to be installed in the runtime image
* goplay2 is not compiled the way it should, and has a number of issues:
  * it will create its configuration and write data under the current working directory
  * config and data are mixed in the same location

To start goplay2:

```bash
docker run -d --rm \
--name "airplay2" \
--env MDNS_NAME="My Fancy Airplay 2 Receiver" \
--group-add audio \
--device /dev/snd \
--net host \
--cap-drop ALL \
--cap-add NET_BIND_SERVICE \
--read-only \
ghcr.io/dubo-dubon-duponey/airplay
```


## Moar?

See [DEVELOP.md](DEVELOP.md)
