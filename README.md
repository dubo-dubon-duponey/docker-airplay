# What

A Docker image to run an AirPlay 2 receiver.

This is based on [shairport-sync](https://github.com/mikebrady/shairport-sync), [nqptp](https://github.com/mikebrady/nqptp) and the [ALAC](https://github.com/mikebrady/alac) library.

NOTE: the awesome mikebrady has an *official* shairport-sync [on Docker Hub](https://hub.docker.com/r/mikebrady/shairport-sync).
You should *really* try it *first* and make it work, and only come back here if you have *good* reasons to do so.

These reasons could be that you are interested in:
* tighter container security (no root, limited caps, hardened)
* opinions (alsa only, Debian)
* more opinions

## Image features

* multi-architecture:
  * [x] linux/amd64
  * [x] linux/arm64
  * [x] linux/arm/v7
* hardened:
  * [x] image runs read-only
  * [x] image runs with only NET_BIND_SERVICE, necessary for nqptp to bind on privileged ports
  * [x] process runs as a non-root user, disabled login, no shell
  * [x] shairport-sync is compiled with PIE, bind now, stack protection, fortify source and read-only relocations (additionally stack clash protection on amd64)
* lightweight
  * [x] based on our slim [Debian Bullseye](https://github.com/dubo-dubon-duponey/docker-debian)
  * [x] simple entrypoint script
  * [ ] multi-stage build with minimal runtime dependencies (libavcodec, avahi-daemon, dbus) 
* observable
  * [x] healthcheck
  * [x] logs to stdout
* other achitectures (arm/v6, 386, ppc64le, s390x) probably build as well, though they are disabled by default

## Run

```bash
docker run -d --rm \
    --name "airplay" \
    --env MDNS_NAME="My Fancy Airplay Receiver" \
    --group-add audio \
    --device /dev/snd \
    --net host \
    --cap-drop ALL \
    --cap-add NET_BIND_SERVICE \
    --read-only \
    docker.io/dubodubonduponey/airplay
```

## Notes

### Networking

You need to run this with `--net host` or alternatively use mac(or ip)vlan networking (because of mDNS).

### Additional arguments

The following environment variables allow for high-level control over shairport:

* MDNS_NAME controls the announced name
* OUTPUT (alsa|pipe|stdout) controls the output
* DEVICE (example: `default:CARD=Mojo`) controls the output device (default to "default")
* LOG_LEVEL if set to "debug" will pass along `-vvv` and `--statistics` to shairport (noisy!)
* PORT controls the port to bind to (defaults to 7000)

Any additional arguments passed when running the image will get fed to the `shairport-sync` binary directly.

You can get a full list of shairport supported arguments with:

```bash
docker run --rm docker.io/dubodubonduponey/airplay --help
```

This is specifically convenient to address a different mixer.

### Custom configuration file

For more advanced control over `shairport-sync` configuration, mount `/config/shairport-sync/main.conf`.

### About soxr

In our experience, soxr yields bad results on RPI 3b.
We advise against using it on low-end hardware.

### About mDNS

This image had been using tinymdns for a long time.
Unfortunately, tiny is abandoned and shairport-sync does not support airplay2 with it.

Therefore, we switched back to avahi/dbus, hopefully run with a non-root user and no cap.

### About other options

We compile only for alsa, and disabled a number of optional features.
See the Dockerfile for details.

## Moar?

See [DEVELOP.md](DEVELOP.md)
