# API Reference

```lua
local Wamp = require 'dmc_corona.dmc_wamp'
```

A `Wamp` object is a [dmc-websockets](https://github.com/dmccuskey/dmc-websockets) connection that speaks WAMP v2 over it. It connects when it's created, joins a realm on a WAMP router, and then lets the app call and offer procedures (RPC) and publish and subscribe to topics (PubSub).

WAMP passes data as two tables: `args`, used as an array, and `kwargs`, used as a dictionary. Either can be left out. For the details of the protocol, see the [WAMP specification](https://wamp-proto.org/spec.html).

The results of calls, subscriptions, publications and registrations arrive in the handler function given to each method; events about the connection arrive through the object's listener (`wamp.EVENT`).

## Creating a Connection

```lua
local wamp = Wamp{
	uri='ws://127.0.0.1/ws',
	port=8080,
	realm='realm1',
}
wamp:addEventListener( wamp.EVENT, wampEvent_handler )
```

`Wamp:new{ ... }` works the same way. The connection starts right away; wait for [`ONJOIN`](#events) before calling any other method (before then, they raise an error).

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
| `wamp.ONCONNECT` | The WebSocket connection opened; the realm is being joined | |
| `wamp.ONCHALLENGE` | The router asked for [authentication](#authentication); the `onChallenge` function answers it | `event.challenge.method`, `event.challenge.extra` |
| `wamp.ONJOIN` | The realm was joined (after authentication, if any); the session is ready | `event.details`: `session` (the session id), `authid`, `authrole`, `authmethod` |
| `wamp.ONDISCONNECT` | The session or connection ended. Sent once per connection | `event.reason`, `event.message`, and `event.code` when the WebSocket connection closed with one |
| `wamp.ONERROR` | The WebSocket connection failed (e.g. the router can't be reached), or a WAMP message couldn't be handled. `ONDISCONNECT` follows | `event.code`, `event.reason`, from [dmc-websockets](https://github.com/dmccuskey/dmc-websockets/blob/master/docs/api.md#close-and-error-codes) |

`ONDISCONNECT`'s `event.reason` says why:

| `event.reason` | Why |
|---|---|
| `'wamp.close.normal'` | After `leave()` (or the reason given to it) |
| `'wamp.error.not_authorized'`, `'wamp.error.no_such_realm'`, ... | The router refused to let the app join; `event.message` says why |
| `'wamp.close.system_shutdown'`, ... | The router ended the session |
| `'wamp.close.transport_lost'` | The connection closed while joined (the router stopped, the network dropped, or the app called `close()`), or before the realm was joined (the router couldn't be reached); `event.message` has the WebSocket reason, if any |

Pending calls, subscriptions, publications and registrations then get an error event. dmc-websockets' `ONOPEN`, `ONMESSAGE` and `ONCLOSE` aren't sent: the WAMP layer handles them.

## Errors

When the router refuses a request (a call to a procedure nobody offers, a name already registered, permission denied), the handler gets its usual event with `event.is_error` set and `event.error`, an error object:

| Field | Description |
|---|---|
| `event.error.error` | The WAMP error URI, such as `'wamp.error.no_such_procedure'` |
| `event.error.message` | The router's message (or the URI, if there's none) |
| `event.error.args`, `event.error.kwargs` | Any data that came with it |

When the connection closes before the reply, `event.error` is a "WAMP transport lost" error, with `message` but no `error` URI.

## Calling Procedures

### call()

```lua
wamp:call( procedure, handler, params )
```

Calls the procedure `procedure` (a URI string such as `'com.example.add2'`), offered by another client of the router. `params` is optional: `args` and `kwargs` are the arguments, and `options` the call options below.

```lua
local function onResult( event )
	if event.type == Wamp.ONRESULT and event.is_error then
		print( 'failed:', event.error.error )
	elseif event.type == Wamp.ONRESULT then
		print( event.data )
	end
end

wamp:call( 'com.example.add2', onResult, { args={ 2, 3 } } )
```

The handler gets one event:

| `event.type` | Fields |
|---|---|
| `Wamp.ONRESULT` | `event.results` (array), `event.kwresults` (dictionary), and `event.data`, the single result, when there is exactly one and no `kwresults` |
| `Wamp.ONRESULT` with `event.is_error` | `event.error`, see [Errors](#errors), e.g. `event.error.error` `'wamp.error.no_such_procedure'` |
| `Wamp.ONPROGRESS` | With `receive_progress`: a progressive result, `event.args` and `event.kwargs`, before the final `ONRESULT` |

Call options, in `params.options`:

| Option | Description |
|---|---|
| `timeout` | Milliseconds. Passed to the router; Crossbar.io passes it on to the callee, which is expected to cancel the call (a dmc-wamp callee doesn't) |
| `receive_progress` | `true` asks for progressive results, sent as `ONPROGRESS` events, if the callee sends them |

```lua
wamp:call( 'com.example.slow', onResult, { args={ 1 }, options={ timeout=5000 } } )
```

## Offering Procedures

### register()

```lua
wamp:register( procedure_function, { procedure=uri, callback=handler } )
```

Offers `procedure_function` to the other clients of the router under the name `uri`. When a client calls it, the function gets the call's `args` and `kwargs` tables and returns its result:

```lua
local function multiply( args, kwargs )
	return args[1] * args[2]
end

local function onRegistered( event )
	if event.is_error then
		print( 'refused:', event.error.error ) -- e.g. 'wamp.error.procedure_already_exists'
	else
		print( 'registered' )
	end
end

wamp:register( multiply, { procedure='com.example.multiply', callback=onRegistered } )
```

What the function returns:

| Return | The caller gets |
|---|---|
| a value (`return 42`, a string, any table) | that one result, as `event.data` |
| nothing | no results |
| `{ results={ ... }, kwresults={ ... } }`, a table with only these keys | `event.results` and `event.kwresults` as given |

A function that raises an error sends the caller an error, `'wamp.error.runtime_error'` with the error message (and prints it). To send your own error URI, raise a `Wamp.ApplicationError`:

```lua
local function divide( args )
	if args[2] == 0 then
		error( Wamp.ApplicationError{ error='com.example.error.divide_by_zero', args={ 'divide by zero' } } )
	end
	return args[1] / args[2]
end
```

The optional `callback` gets `Wamp.ONREGISTERED` once the router has accepted the registration (`event.registration`), or refused it (`event.is_error`, `event.error`). Without a callback, a refusal is printed. `params.pkeys` and `params.disclose_caller` are passed to the router as register options.

### unregister()

```lua
wamp:unregister( procedure_function, { callback=handler } )
```

Withdraws a procedure, given the same function as `register()`. The optional `callback` gets `Wamp.ONUNREGISTERED` once the router confirms (or `event.is_error`). A function that isn't registered raises an error.

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

With `params.callback`, the router is asked to acknowledge the publication, and the callback gets a `Wamp.ONPUBLISHED` event when it has accepted it (`event.publication.id`), or refused it (`event.is_error`, `event.error`):

```lua
local function onPublished( event )
	if not event.is_error then print( 'published', event.publication.id ) end
end

wamp:publish( 'com.myapp.topic1', { args={ 'hello' }, callback=onPublished } )
```

## Leaving

### leave()

```lua
wamp:leave( reason )
```

Leaves the realm. `reason` is a WAMP URI and defaults to `'wamp.close.normal'`. The router confirms, the connection closes, and the listener gets `ONDISCONNECT` with that reason. Calling it again before then raises an error; after the session ended, it only prints a notice.

### close()

```lua
wamp:close()
```

Closes the connection without leaving the realm first: the listener gets `ONDISCONNECT` with `'wamp.close.transport_lost'`, and the router sees a lost connection. Prefer `leave()` while the realm is joined.

## Properties

| Property | Description |
|---|---|
| `wamp.is_connected` | `true` while the realm is joined: from `ONJOIN` until the session ends |
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

The function gets an event with `event.method` (`Wamp.AUTH_WAMPCRA` or `Wamp.AUTH_TICKET`), `event.extra` (the method's data from the router; for WAMP-CRA, `event.extra.challenge`), and `event.session` (the `Wamp` object). The function returns the answer as a string. The listener gets `ONCHALLENGE` just before the function is called. A refused login ends the session: the listener gets `ONDISCONNECT` instead of `ONJOIN`, with `event.reason` `'wamp.error.not_authorized'` and a `event.message` such as `'WAMP-CRA signature is invalid'`.

`Auth.compute_wcs( key, challenge )` signs the challenge with HMAC-SHA256 using Solar2D's `crypto` library. **Salted WAMP-CRA:** a router can store a key derived from the secret with PBKDF2 instead of the secret (in Crossbar.io, a user with `salt`, `iterations` and `keylen`). `Auth.derive_key()`, which would derive it from the secret, isn't implemented yet; pass the derived key itself to `compute_wcs()`. The router setup in [`examples/router/`](../examples/router/README.md) has a user of each kind: `joe` with a plain secret and `peter` with a derived key.

## Constants

| Constant | Value |
|---|---|
| `Wamp.EVENT` | `'wamp_event'`, the listener's event name |
| `Wamp.ONCONNECT`, `Wamp.ONCHALLENGE`, `Wamp.ONJOIN`, `Wamp.ONDISCONNECT` | Connection events, see [Events](#events) |
| `Wamp.ONERROR` | `'onerror'`, from dmc-websockets |
| `Wamp.ONRESULT`, `Wamp.ONPROGRESS` | Call handler events |
| `Wamp.ONSUBSCRIBED`, `Wamp.ONPUBLISH`, `Wamp.ONUNSUBSCRIBED` | Subscription handler events |
| `Wamp.ONPUBLISHED` | Publish callback event |
| `Wamp.ONREGISTERED`, `Wamp.ONUNREGISTERED` | Register and unregister callback events |
| `Wamp.VERSION` | The library's version, e.g. `'1.1.0'` |
| `Wamp.ApplicationError` | The error class a registered procedure can raise, see [register()](#register) |
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

Checked against Crossbar.io in October 2026:

- A dmc-wamp callee doesn't enforce a call's `timeout`, send progressive results, or support call canceling ([#6](https://github.com/dmccuskey/dmc-wamp/issues/6)).
- `Auth.derive_key()`, `Auth.pbkdf2()`, `Auth.generate_wcs()` and the TOTP helpers raise "not implemented": no salted WAMP-CRA ([#1](https://github.com/dmccuskey/dmc-wamp/issues/1)).
- Only JSON serialization; no MessagePack ([#2](https://github.com/dmccuskey/dmc-wamp/issues/2)).
- Objects can't be registered as a group of procedures (`register()` with a table raises "not implemented") ([#3](https://github.com/dmccuskey/dmc-wamp/issues/3)).
- No subscription options (such as prefix or wildcard matching) and no publish options (such as `exclude_me`) ([#4](https://github.com/dmccuskey/dmc-wamp/issues/4)).
- `wss://` hasn't been tested with a WAMP router ([#5](https://github.com/dmccuskey/dmc-wamp/issues/5)).
- A malformed URI (such as one with a space) is a protocol violation: Crossbar.io closes the connection rather than answering with an error, and the listener gets `ONDISCONNECT`.
