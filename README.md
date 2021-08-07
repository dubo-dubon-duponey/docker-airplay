# What

A Docker image to run an Apple AirPlay receiver.

This is based on [shairport-sync](https://github.com/mikebrady/shairport-sync) and the [ALAC](https://github.com/mikebrady/alac) library.

## Image features

* multi-architecture:
  * [x] linux/amd64
  * [x] linux/386
  * [x] linux/arm64
  * [x] linux/arm/v7
  * [x] linux/arm/v6
  * [x] linux/ppc64
  * [x] linux/s390x
* hardened:
  * [x] image runs read-only
  * [x] image runs with no capabilities (unless you want it on port 443)
  * [x] process runs as a non-root user, disabled login, no shell
  * [x] binaries are compiled with PIE, bind now, stack protection, fortify source and read-only relocations (additionally stack clash protection on amd64)
* lightweight
  * [x] based on our slim [Debian bullseye version (2021-08-01)](https://github.com/dubo-dubon-duponey/docker-debian)
  * [x] simple entrypoint script
  * [x] multi-stage build with no installed dependencies for the runtime image
* observable
  * [x] healthcheck
  * [x] logs to stdout
  * [ ] ~~prometheus endpoint~~

## Run

```bash
docker run -d --rm \
    --name "airport" \
    --env NAME="My Fancy Airplay Receiver" \
    --group-add audio \
    --device /dev/snd \
    --net host \
    --cap-drop ALL \
    --read-only \
    dubodubonduponey/shairport-sync
```

## Notes

### Networking

You need to run this in `host` or `mac(or ip)vlan` networking (because of mDNS).

### Additional arguments

The following environment variables allow for high-level control over shairport:

* LOG_LEVEL if set to "debug" will pass along -vvv and --statistics
* OUTPUT (alsa|pipe|stdout) controls the output
* MDNS_NAME controls the announced name
* PORT controls the port to bind to

Any additional arguments passed when running the image will get fed to the `shairport-sync` binary directly.

You can get a full list of supported arguments by simply calling

```
docker run --rm dubodubonduponey/shairport-sync --help
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

### About Airplay 2

Unsupported right now, and it appears unlikely to be implemented in shairport-sync for the time being.
See https://github.com/mikebrady/shairport-sync/issues/535 for details.

Alternative projects like https://github.com/openairplay/ may have proper support one day, but are untested by us right now.

## Moar?

See [DEVELOP.md](DEVELOP.md)
