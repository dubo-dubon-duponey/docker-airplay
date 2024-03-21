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
* hardened:
  * [x] image runs read-only
  * [x] image runs with ~~no capabilities~~ NET_BIND_SERVICE, necessary for nqptp to bind on privileged ports
  * [x] process runs as a non-root user, disabled login, no shell
  * [x] compiled with PIE, bind now, stack protection, fortify source and read-only relocations (additionally stack clash protection on amd64)
* lightweight
  * [x] based on our slim [Debian Bookworm](https://github.com/dubo-dubon-duponey/docker-debian)
  * [x] simple entrypoint script
  * [ ] multi-stage build with ~~zero packages~~ `libavcodec`, `avahi-daemon` and `dbus` installed in the runtime image 
* observable
  * [x] healthcheck
  * [x] logs to stdout
  * [ ] ~~prometheus endpoint~~ not applicable - one should rather monitor containers using a dedicated prometheus endpoint

## Run

```bash
docker run -d --rm \
    --name "airplay" \
    --env MOD_MDNS_NAME="My Fancy Airplay Receiver" \
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

* MOD_MDNS_NAME controls the announced name
* OUTPUT (alsa|pipe|stdout) controls the output
* DEVICE (example: `default:CARD=Mojo`) controls the output device (default to "default")
* LOG_LEVEL - debug, info, warning, error
* ADVANCED_AIRPLAY_PORT controls the port to bind to (defaults to 7000)
* STUFFING (basic or soxr) controls the stuffing mode (see soxr section below)

Any additional arguments passed when running the image will get fed to the `shairport-sync` binary directly.

You can get a full list of shairport supported arguments with:

```bash
docker run --rm docker.io/dubodubonduponey/airplay --help
```

This is specifically convenient to address a different mixer.

### Custom configuration file

For more advanced control over `shairport-sync` configuration:
* mount `/magnetar/user/config/shairport-sync/main.conf`.
* make sure permissions are fine: `chown 2000`
* add whichever configuration you want aggregated to the default configuration

### About soxr

In our experience, soxr yields bad results on RPI 3b.
We advise against using it on low-end hardware.
Henceforth, default in the image is "basic".
If you want soxr, use `STUFFING=soxr`

### About mDNS

This image had been using tinymdns for a long time.
Unfortunately, tiny is abandoned and shairport-sync does not support airplay2 with it.

Therefore, we switched back to avahi/dbus, hopefully run with a non-root user and no cap.

### About other options

We compile only for alsa, and disabled a number of optional features.

See the Dockerfile for details.

## Moar?

See [DEVELOP.md](DEVELOP.md)
