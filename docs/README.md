# dmc-wamp Documentation

New here? The [Quick Start](../README.md#quick-start) gets a Solar2D app calling procedures and receiving events through a WAMP router in about 15 minutes.

## Start

- [Quick Start](../README.md#quick-start): start a router, copy the library in, join a realm, call and subscribe
- [Installation](https://github.com/dmccuskey/dmc-websockets/blob/master/docs/installation.md): what to copy, plugins, Android (dmc-websockets' guide applies unchanged)

## Use

- [API reference](api.md): connection options, events, calling and offering procedures, publishing and subscribing, authentication, configuration, known issues
- [Examples](../examples/README.md): a caller, a callee, a publisher, a subscriber and an authenticated client
- [Changelog](../CHANGELOG.md)
- [Router for the examples](../examples/router/README.md): Crossbar.io in Docker, with a backend to talk to

## Internals

- [WAMP specification](https://wamp-proto.org/spec.html): the protocol, WAMP v2
- [AutobahnPython](https://github.com/crossbario/autobahn-python): the WAMP client dmc-wamp was ported from; its session code (`autobahn/wamp/protocol.py`) matches `dmc_corona/dmc_wamp/protocol.lua`
- [dmc-websockets](https://github.com/dmccuskey/dmc-websockets): the WebSocket connection underneath

## Contribute

- [Development](development.md): testing, rebuilding the bundled libraries
- [Issues](https://github.com/dmccuskey/dmc-wamp/issues)

## Project Structure

```text
README.md                   landing page and Quick Start
CHANGELOG.md
LICENSE
docs/                       this documentation
dmc_corona/                 what apps copy
├── dmc_wamp.lua            the WAMP client (source)
├── dmc_wamp/               session, messages, serializer, auth, errors (source)
├── dmc_websockets*         from dmc-websockets (generated copy)
├── dmc_sockets*            from dmc-sockets (generated copy)
└── lib/                    sha1.lua (dmc-websockets) and dmc_lua/ (generated copies)
dmc_corona_boot.lua         loader, from dmc-corona-boot (generated copy)
dmc_corona.cfg              library configuration
examples/                   sample apps, each with its own generated dmc_corona/
└── router/                 Crossbar.io router configuration and backend
Snakefile                   build rules for the generated copies
tests/                      unit tests (tests/run_unit.sh)
```
