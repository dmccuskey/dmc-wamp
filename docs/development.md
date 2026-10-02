# Development

How to test dmc-wamp and rebuild the libraries it bundles.

## Testing

### Unit Tests

`tests/dmc_wamp_spec.lua` tests the messages, and a session driven through a stand-in transport with messages as a router sends them: errors, publish acknowledgments, call options, register and unregister, invocation replies, leaving and lost connections, challenges. Run it with plain Lua 5.1 and [dkjson](https://luarocks.org/modules/dhkolf/dkjson):

```sh
tests/run_unit.sh
```

It uses the interpreter in `../tools/lua51/bin/lua`; set `LUA` to use another.

### Against a Router

The examples test the rest against a real WAMP router:

1. Start the router in [`examples/router/`](../examples/router/README.md) (Crossbar.io in Docker, with a small backend that offers a procedure and publishes on a topic).
2. Open each example's `main.lua` in the Solar2D Simulator and compare its console output with the [examples README](../examples/README.md).

The authentication example needs the Simulator (it uses Solar2D's `crypto` library). The others also run in plain Lua 5.1 inside [lua-corovel](https://github.com/dmccuskey/lua-corovel), the way dmc-websockets runs its [Autobahn tests](https://github.com/dmccuskey/dmc-websockets/blob/master/docs/development.md#autobahn-testsuite).

To see the messages the client sends, set `DEBUG_ACTIVE` in the `[DMC_WAMP]` section of the example's `dmc_corona.cfg` ([Configuration](api.md#configuration)); the router's log (`docker logs wamp-router`) shows its side.

## Bundled Libraries

`dmc_corona/` holds copies of the libraries dmc-wamp uses, so an app only has to copy one folder. The copies are generated, not edited by hand:

| Code | Lives in |
|---|---|
| `dmc_corona/dmc_wamp*` | this repository (the source) |
| `dmc_corona/dmc_websockets*`, `dmc_corona/lib/sha1.lua` | [dmc-websockets](https://github.com/dmccuskey/dmc-websockets) |
| `dmc_corona/dmc_sockets*` | [dmc-sockets](https://github.com/dmccuskey/dmc-sockets) |
| `dmc_corona/lib/dmc_lua/` | [DMC-Lua-Library](https://github.com/dmccuskey/DMC-Lua-Library) |
| `dmc_corona_boot.lua` | [dmc-corona-boot](https://github.com/dmccuskey/dmc-corona-boot) |

To fix something in a bundled library, change it in its own repository, then rebuild the copies here and in `examples/` with [Snakemake](https://snakemake.readthedocs.io/) (version 7). The build expects the other repositories checked out beside this one, and uses DMC-Corona-Library's shared rules:

```sh
snakemake --cores 1 --forceall build_all
```

The copies come from the sibling checkouts as they are on disk, on whatever branch each has checked out.

## Branches

Changes go on a short-lived branch (`fix/...`, `feat/...`, `docs/...`) and are merged into `master`.
