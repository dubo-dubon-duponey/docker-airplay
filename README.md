# What

A Docker image to run an Apple AirPlay receiver.

This is based on [shairport-sync](https://github.com/mikebrady/shairport-sync) and the [ALAC](https://github.com/mikebrady/alac) library.

## Image features

 * multi-architecture:
    * [x] linux/amd64
    * [x] linux/arm64
    * [x] linux/arm/v7
    * [x] linux/arm/v6
 * hardened:
    * [x] image runs read-only
    * [x] image runs with no capabilities
    * [x] process runs as a non-root user, disabled login, no shell
 * lightweight
    * [x] based on our slim [Debian buster version](https://github.com/dubo-dubon-duponey/docker-debian)
    * [x] simple entrypoint script
    * [ ] multi-stage build with ~~no installed~~ dependencies for the runtime image:
      * libdaemon0
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
docker run -d \
    --env NAME="My Fancy Airplay Receiver" \
    --net host \
    --name airplay \
    --read-only \
    --cap-drop ALL \
    --group-add audio \
    --device /dev/snd \
    --rm \
    dubodubonduponey/shairport-sync:v1
```

## Notes

### Custom configuration file

For advanced control over shairport-sync configuration, mount `/config/shairport-sync.conf`.

Also, any additional arguments when running the image will get fed to the `shairport-sync` binary.

This is specially convenient to address a different Alsa card or mixer (eg: `-- -d hw:1`), or enable statistics logging (`--statistics`) or verbose logging (`-vvv`).

### Networking

You need to run this in host or macvlan networking (because: mDNS).

If you want to run multiple instances on the same host, then macvlan (or ipvlan) is your only choice.

#### Build time

You can rebuild the image using the following build arguments:

 * BUILD_UID
 
So to control which user-id to assign to the in-container user.

## Notes

### Network

 * `bridge` mode will NOT work for discovery, since mDNS will not broadcast on your lan subnet
 * `host` (default, easy choice) is only acceptable as long as you DO NOT have any other containers running on the same ip using avahi

If you intend on running multiple containers relying on avahi, you may want to consider `macvlan`.

TL;DR:

```bash
docker network create -d macvlan \
  --subnet=192.168.1.0/24 \
  --ip-range=192.168.1.128/25 \
  --gateway=192.168.1.1 \
  -o parent=eth0 hackvlan
  
docker run -d --env NAME=N1 --device=/dev/snd --name=N1 --network=hackvlan dubodubonduponey/shairport-sync:v1
docker run -d --env NAME=N2 --device=/dev/snd --name=N2 --network=hackvlan dubodubonduponey/shairport-sync:v1
```

Need help with macvlan?
[Hit yourself up](https://docs.docker.com/network/macvlan/).

### Advanced configuration

Would you need to, you may optionally pass along:
 
 * `--volume [host_path]/shairport-sync.conf:/etc/shairport-sync.conf` if you want to tweak shairport configuration at runtime
 * `--volume [host_path]/avahi-daemon.conf:/etc/avahi/avahi-daemon.conf` if you need to tweak avahi

Also, any additional arguments when running the image will get fed to the shairport binary.

### Base OS

I gave up on alpine. git history for posterity.

Main differences compared to `kevineye` image:

 * based on debian or vanilla alpine (3.9) instead of resin / balena
 * generates a multi-architecture image (amd64, arm64, amrv7, armv6)
 * shairport-sync source is forked on github under `dubo-dubon-duponey`
 * tested daily for many hours in production (sitting at my desk) on a raspberrypi armv7
