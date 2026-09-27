# API Reference

```lua
local Wamp = require 'dmc_corona.dmc_wamp'
```

A `Wamp` object is a [dmc-websockets](https://github.com/dmccuskey/dmc-websockets) connection that speaks WAMP v2 over it. It connects when it's created, joins a realm on a WAMP router, and then lets the app call and offer procedures (RPC) and publish and subscribe to topics (PubSub).

WAMP passes data as two tables: `args`, used as an array, and `kwargs`, used as a dictionary. Either can be left out. For the details of the protocol, see the [WAMP specification](https://wamp-proto.org/spec.html).

The results of calls, subscriptions and publications arrive in the handler function given to each method; events about the connection arrive through the object's listener (`wamp.EVENT`).

## Creating a Connection

```lua
local wamp = Wamp{
	uri='ws://127.0.0.1/ws',
	port=8080,
	realm='realm1',
}
wamp:addEventListener( wamp.EVENT, wampEvent_handler )
```

`Wamp:new{ ... }` works the same way. The connection starts right away; wait for [`ONJOIN`](#events) before calling any other method.

### Options

| Option | Default | Description |
|---|---|---|
| `uri` | required | Router address, `ws://` or `wss://`, with the path (e.g. `/ws`) but without the port |
| `port` | `80` or `443` | Router port |
| `realm` | required | The realm to join |
| `protocols` | `{ 'wamp.2.json' }` | WebSocket subprotocols; JSON is the only serializer |
| `user_id` | | For [authentication](#authentication): the user name (WAMP `authid`) |
| `auth_methods` | | For [authentication](#authentication): a list such as `{ 'wampcra' }` or `{ 'ticket' }` |
| `onChallenge` | | For [authentication](#authentication): a function that answers the router's challenge |

Everything else is passed to dmc-websockets, such as the [TLS settings](https://github.com/dmccuskey/dmc-websockets/blob/master/docs/api.md#tls-settings) for `wss://` and `throttle`. `wss://` hasn't been tested with a WAMP router yet.

## Events

All events about the connection arrive through one listener:

```lua
local function wampEvent_handler( event )
	if event.type == wamp.ONJOIN then
		-- ready: call, register, publish, subscribe
	elseif event.type == wamp.ONDISCONNECT then
		print( 'left the realm:', event.reason )
	end
end
```

| `event.type` | When | Fields |
|---|---|---|
| `wamp.ONJOIN` | The realm was joined (after authentication, if any); the session is ready | |
| `wamp.ONDISCONNECT` | The session ended: after `leave()`, or when the router ends it or refuses the login | `event.reason`, e.g. `'wamp.close.normal'`, and `event.message` |
| `wamp.ONERROR` | The WebSocket connection failed, or a WAMP message couldn't be handled (the connection is then closed) | `event.code`, `event.reason`, from [dmc-websockets](https://github.com/dmccuskey/dmc-websockets/blob/master/docs/api.md#close-and-error-codes) |

`wamp.ONCONNECT` and `wamp.ONCHALLENGE` are defined but never sent. dmc-websockets' `ONOPEN`, `ONMESSAGE` and `ONCLOSE` aren't sent either: the WAMP layer handles them. A router that can't be reached gives no event at all ([Known Issues](#known-issues)).

## Calling Procedures

### call()

```lua
wamp:call( procedure, handler, params )
```

Calls the procedure `procedure` (a URI string such as `'com.example.add2'`), offered by another client of the router. `params` is optional: `args` and `kwargs` are the arguments.

```lua
local function onResult( event )
	if event.type == Wamp.ONRESULT and not event.is_error then
		print( event.data )
	end
end

wamp:call( 'com.example.add2', onResult, { args={ 2, 3 } } )
```

The handler gets one event:

| `event.type` | Fields |
|---|---|
| `Wamp.ONRESULT` | `event.results` (array), `event.kwresults` (dictionary), and `event.data`, the single result, when there is exactly one and no `kwresults` |
| `Wamp.ONRESULT` with `event.is_error` | `event.error`. Not sent yet: a failed call never calls the handler ([Known Issues](#known-issues)) |

`Wamp.ONPROGRESS` (progressive results) and call options such as a timeout aren't supported yet.

## Offering Procedures

### register()

```lua
wamp:register( procedure_function, { procedure=uri } )
```

Offers `procedure_function` to the other clients of the router under the name `uri`. When a client calls it, the function gets the call's `args` and `kwargs` tables and must return its results as a table with `results` (array) and/or `kwresults` (dictionary):

```lua
local function multiply( args, kwargs )
	return { results={ args[1] * args[2] } }
end

wamp:register( multiply, { procedure='com.example.multiply' } )
```

A caller that gets exactly one result sees it as `event.data`. The function must return a table: a plain value (`return 42`) or nothing closes the connection with an error. `register()` doesn't report when the router has accepted the registration, or refused it (for example, because another client already offers that name).

### unregister()

```lua
wamp:unregister( procedure_function )
```

Meant to withdraw a procedure, given the same function as `register()`. It doesn't work yet: it raises an error ([Known Issues](#known-issues)).

## Publishing and Subscribing

### subscribe()

```lua
wamp:subscribe( topic, handler )
```

Subscribes to `topic` (a URI string such as `'com.myapp.topic1'`). The same handler gets the confirmation, then every event published on the topic:

```lua
local function onTopic( event )
	if event.type == Wamp.ONSUBSCRIBED then
		print( 'subscribed' )
	elseif event.type == Wamp.ONPUBLISH then
		print( event.args[1] )
	elseif event.type == Wamp.ONUNSUBSCRIBED then
		print( 'unsubscribed' )
	end
end

wamp:subscribe( 'com.myapp.topic1', onTopic )
```

| `event.type` | When | Fields |
|---|---|---|
| `Wamp.ONSUBSCRIBED` | The router confirmed the subscription | `event.subscription` |
| `Wamp.ONPUBLISH` | Someone published on the topic | `event.args`, `event.kwargs` |
| `Wamp.ONUNSUBSCRIBED` | After `unsubscribe()`, the router confirmed | |

A client doesn't receive its own publications.

### unsubscribe()

```lua
wamp:unsubscribe( topic, handler )
```

Ends the subscription made with the same `topic` and `handler`; the handler then gets `Wamp.ONUNSUBSCRIBED`. A pair that wasn't subscribed raises an error.

### publish()

```lua
wamp:publish( topic, params )
```

Publishes an event on `topic` to its subscribers. `params` holds `args` and `kwargs`, the event's data:

```lua
wamp:publish( 'com.myapp.topic1', { args={ 'hello' } } )
```

`params.callback` is meant to get a `Wamp.ONPUBLISHED` event when the router has accepted the publication, but it's never called yet ([Known Issues](#known-issues)); the publication itself is delivered.

## Leaving

### leave()

```lua
wamp:leave( reason )
```

Leaves the realm. `reason` is a WAMP URI and defaults to `'wamp.close.normal'`. The router confirms, the connection closes, and the listener gets `ONDISCONNECT`. Calling it again before then raises an error; after the session ended, it only prints a notice.

### close()

```lua
wamp:close()
```

Closes the connection without leaving the realm first. Don't use it while the realm is joined: it raises an error there ([Known Issues](#known-issues)); use `leave()`.

## Properties

| Property | Description |
|---|---|
| `wamp.is_connected` | `true` from when the WebSocket connection opens until the session ends. It's already `true` before the realm is joined: wait for `ONJOIN` |
| `wamp.user_id` | Set only: changes the `user_id` option before the realm is joined |
| `wamp.auth_methods` | Set only: changes the `auth_methods` option before the realm is joined |

## Authentication

The router decides which users may join and what each may call, register, publish and subscribe. Two methods are supported, [WAMP-CRA](https://wamp-proto.org/wamp_latest_ietf.html#name-challenge-response-authenti) (challenge-response: the secret is never sent) and tickets (the secret is sent as is, so use them only over `wss://`). Give the user name, the methods to offer, and a function that answers the router's challenge:

```lua
local Wamp = require 'dmc_corona.dmc_wamp'
local Auth = require 'dmc_corona.dmc_wamp.auth'

local function onChallenge( event )
	if event.method == Wamp.AUTH_WAMPCRA then
		return Auth.compute_wcs( 'secret2', event.extra.challenge )
	elseif event.method == Wamp.AUTH_TICKET then
		return 'secret!!!'
	end
end

local wamp = Wamp{
	uri='ws://127.0.0.1/auth',
	port=8080,
	realm='realm1',
	user_id='joe',
	auth_methods={ 'wampcra' },
	onChallenge=onChallenge,
}
```

The challenge event has `event.method` (`Wamp.AUTH_WAMPCRA` or `Wamp.AUTH_TICKET`), `event.extra` (the method's data from the router; for WAMP-CRA, `event.extra.challenge`), and `event.session` (the `Wamp` object). The function returns the answer as a string. A refused login ends the session: the listener gets `ONDISCONNECT` instead of `ONJOIN`, with `event.reason` `'wamp.error.not_authorized'` and a `event.message` such as `'WAMP-CRA signature is invalid'`.

`Auth.compute_wcs( key, challenge )` signs the challenge with HMAC-SHA256 using Solar2D's `crypto` library. **Salted WAMP-CRA:** a router can store a key derived from the secret with PBKDF2 instead of the secret (in Crossbar.io, a user with `salt`, `iterations` and `keylen`). `Auth.derive_key()`, which would derive it from the secret, isn't implemented yet; pass the derived key itself to `compute_wcs()`. The router setup in [`examples/router/`](../examples/router/README.md) has a user of each kind: `joe` with a plain secret and `peter` with a derived key.

## Constants

| Constant | Value |
|---|---|
| `Wamp.EVENT` | `'wamp_event'`, the listener's event name |
| `Wamp.ONJOIN`, `Wamp.ONDISCONNECT` | Connection events, see [Events](#events) |
| `Wamp.ONERROR` | `'onerror'`, from dmc-websockets |
| `Wamp.ONRESULT`, `Wamp.ONPROGRESS` | Call handler events |
| `Wamp.ONSUBSCRIBED`, `Wamp.ONPUBLISH`, `Wamp.ONUNSUBSCRIBED` | Subscription handler events |
| `Wamp.ONPUBLISHED` | Publish callback event |
| `Wamp.AUTH_WAMPCRA`, `Wamp.AUTH_TICKET` | `'wampcra'`, `'ticket'` |
| `Wamp.DEFAULT_PROTOCOL` | `{ 'wamp.2.json' }` |

## Configuration

dmc-wamp's `dmc_corona.cfg` section, `[DMC_WAMP]`, has one setting and can be left out or left empty:

| Option | Default | Description |
|---|---|---|
| `DEBUG_ACTIVE` | `false` | `true` prints each WAMP message as it's sent, as JSON: `dmc_wamp:send() :: sending	[48,220861719,{},"com.example.add2",[2,3]]` |

```ini
[DMC_WAMP]
DEBUG_ACTIVE:BOOL = true
```

Connection settings go in the [options](#options) of each connection instead. How often sockets are checked can also be set for the whole app in dmc-sockets' `[DMC_SOCKETS]` section ([dmc-sockets Configuration](https://github.com/dmccuskey/dmc-sockets/blob/master/docs/api.md#configuration)). The file's format, and the `[DMC_CORONA]` section every DMC library uses, are described in [dmc-corona-boot's Configuration](https://github.com/dmccuskey/dmc-corona-boot/blob/master/docs/configuration.md).

## Known Issues

Checked against Crossbar.io in September 2026. The first six break normal use and are planned to be fixed first:

- **A lost connection crashes the app:** when the connection closes while the realm is joined (the router stops, the network drops, or the app calls `close()`), the session tries to send its goodbye over the closed transport and raises an uncaught error (`Session:disconnect :: transport not available`). End sessions with `leave()`.
- **Errors from the router are lost, and break the connection:** an `ERROR` message (a call to a procedure nobody offers, a call that fails, permission denied) isn't parsed correctly (`args` and `kwargs` are read from the wrong positions, and the error URI and request id are dropped), so it's treated as a protocol error: the listener gets `ONERROR` and the connection closes. Once parsed, errors still aren't handled: the session ignores them, so the handler of a failed call, subscribe, publish or register is never called.
- **`publish()`'s callback is never called:** the acknowledgment option isn't passed on to the router. Passed on, the router's reply would fail, since the `Publication` is created with the wrong field name (`publication` instead of `publication_id`), and the `ONPUBLISHED` event doesn't carry the publication.
- **`unregister()` raises an error:** it calls `unsubscribe()` on the registration, which only has `unregister()`.
- **A router that can't be reached gives no event:** dmc-websockets reports it as `ONCLOSE`, which the WAMP layer handles without a session, so it sends nothing.
- **A registered procedure must return a table** (`{ results={...} }`); a plain value or nothing closes the connection with an error. AutobahnPython turns a plain return value into the single result.

The rest:

- Call options don't reach the router (the same bug as publish's acknowledgment), so there are no call timeouts and no progressive results (`ONPROGRESS`).
- `register()` doesn't report when a registration is accepted or refused; `register()` with `pkeys` or `disclose_caller` fails on an undefined `Types` (for `WTypes`).
- `ONCONNECT` and `ONCHALLENGE` are never sent; `is_connected` is `true` before the realm is joined.
- `Auth.derive_key()`, `Auth.pbkdf2()`, `Auth.generate_wcs()` and the TOTP helpers raise "not implemented": no salted WAMP-CRA.
- Only JSON serialization; no MessagePack.
- Objects can't be registered as a group of procedures (`register()` with a table raises "not implemented").
- No subscription options (such as prefix or wildcard matching) and no publish options (such as `exclude_me`).
- `close()` reads an undefined global `was_clean`; `Utils.extend()` in `dmc_wamp.lua` leaks the global `_extend`.
- The version (`1.0.0`) isn't exported.
- `wss://` hasn't been tested with a WAMP router.
- No automated tests.
