# Router for the Examples

A WAMP client talks to other clients through a WAMP router. This folder sets up [Crossbar.io](https://crossbar.io/) in Docker for the examples and the Quick Start, with a small backend in Python that gives them something to talk to.

## Start It

From the repository's folder:

```sh
docker run --rm --name wamp-router -p 8080:8080 -v "$PWD/examples/router:/node" crossbario/crossbar
```

It's ready when the log shows `Ok, node has started Container worker002`. The first start takes a minute or two; the image is x86-only, so on Apple Silicon it runs under emulation (add `--platform linux/amd64` to silence the warning). Stop it with Ctrl-C or `docker stop wamp-router`.

Crossbar writes its node key and PID file into `.crossbar/` (ignored by git).

## What It Provides

One realm, `realm1`, on port 8080, with two WebSocket paths:

| Address | Login | Allowed |
|---|---|---|
| `ws://127.0.0.1:8080/ws` | none (anonymous) | everything: call, register, publish, subscribe |
| `ws://127.0.0.1:8080/auth` | WAMP-CRA or ticket, see below | calling `com.example.add2` only |

In dmc-wamp, give the address as `uri` without the port, and the port as `port`: `uri='ws://127.0.0.1/ws', port=8080`.

The backend ([`backend.py`](backend.py), run by the router) joins `realm1` and:

- offers the procedure `com.example.add2`, which returns the sum of its two arguments
- publishes `tick-1`, `tick-2`, ... on the topic `com.myapp.topic1` once a second
- prints whatever others publish on `com.myapp.topic1` (see it with `docker logs wamp-router`)

## Users on `/auth`

| User | WAMP-CRA | Ticket |
|---|---|---|
| `joe` | secret `secret2` | `secret!!!` |
| `peter` | salted: the router stores the key derived from `secret2` (salt `salt123`, 100 iterations, 16 bytes), `prq7+YkJ1/KlW1X0YczMHw==`; the client signs with that key | `secret` |

These are the users of the [authentication example](../dmc-wamp-authentication/), which picks one in its `app_config.lua`. They're test credentials: don't reuse this configuration for a real router.

## Other Setups

To run the router on another computer, run the same command there and change the examples' `app_config.lua` (or your `uri`) to that computer's address. Any WAMP v2 router with JSON over WebSocket works; the examples need a procedure `com.example.add2` and events on `com.myapp.topic1`.
