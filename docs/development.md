# Development

How to test dmc-wamp and rebuild the libraries it bundles.

## Testing

There are no automated tests yet. Test by hand against a WAMP router:

1. Start the router in [`examples/router/`](../examples/router/README.md) (Crossbar.io in Docker, with a small backend that offers a procedure and publishes on a topic).
2. Open each example's `main.lua` in the Solar2D Simulator and compare its console output with the [examples README](../examples/README.md).

The authentication example needs the Simulator (it uses Solar2D's `crypto` library). The others also run in plain Lua 5.1 inside [lua-corovel](https://github.com/dmccuskey/lua-corovel), the way dmc-websockets runs its [Autobahn tests](https://github.com/dmccuskey/dmc-websockets/blob/master/docs/development.md#autobahn-testsuite), with a stand-in `display` table (`dmc_utils` reads it when loaded).

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

The examples' `dmc_corona/` folders also hold `dmc_objects.lua`, `dmc_states_mix.lua` and `dmc_utils.lua`, left from older builds: the Snakefile no longer requires them, so a rebuild doesn't update them. The subscribe and RPC caller examples use `dmc_utils` to print error events.

## Branches

Changes go on a short-lived branch (`fix/...`, `feat/...`, `docs/...`) and are merged into `master`.
