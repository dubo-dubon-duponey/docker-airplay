# What

A Docker image to run an Apple AirPlay receiver.

This is based on [shairport-sync](https://github.com/mikebrady/shairport-sync) and the [ALAC](https://github.com/mikebrady/alac) library.

## Image features

 * multi-architecture:
    * [x] linux/amd64
    * [x] linux/arm64
    * [x] linux/arm/v7
    * [ ] linux/arm/v6 (should build, disabled by default)
 * hardened:
    * [x] image runs read-only
    * [x] image runs with no capabilities
    * [x] process runs as a non-root user, disabled login, no shell
 * lightweight
    * [x] based on our slim [Debian buster version](https://github.com/dubo-dubon-duponey/docker-debian)
    * [x] simple entrypoint script
    * [ ] multi-stage build with ~~no installed~~ dependencies for the runtime image:
      * libasound2
      * libpopt0
      * libsoxr0
      * libconfig9
      * libssl1.1
 * observable
    * [x] healthcheck
    * [x] log to stdout
    * [ ] ~~prometheus endpoint~~ not applicable

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
    dubodubonduponey/shairport-sync:v1
```

## Notes

### Networking

You need to run this in `host` or `mac(or ip)vlan` networking (because of mDNS).

### Additional arguments

Any additional arguments when running the image will get fed to the `shairport-sync` binary.

This is specifically convenient to address a different Alsa card or mixer (eg: `-- -d hw:1`), or enable statistics logging (`--statistics`) or verbose logging (`-vvv`).

### Custom configuration file

For advanced control over shairport-sync configuration, mount `/config/shairport-sync.conf`.

## Moar?

See [DEVELOP.md](DEVELOP.md)
