# Examples

Each folder is a complete Solar2D project with its own copy of the library: open its `main.lua` in the Solar2D Simulator. The examples draw nothing; they print to the Simulator's console.

They all need a WAMP router. Start the one in [`router/`](router/README.md) (Crossbar.io in Docker) first; it also runs a backend that offers the procedure `com.example.add2` and publishes `tick-1`, `tick-2`, ... on `com.myapp.topic1` once a second. Each example's `app_config.lua` holds the router's address (`127.0.0.1`, the same computer), realm, and procedure or topic; change it to use another router.

## RPC Caller

[dmc-wamp-rpc-caller](dmc-wamp-rpc-caller/): joins `realm1`, calls `com.example.add2` with the arguments 2 and 2, prints the result, and leaves two seconds later:

```text
WAMP: Starting WAMP Communication
>> We have WAMP Join
WAMP: successful RESULT
>>  data	4
>>  results	1	4
>> We have WAMP Disconnect
```

## RPC Callee

[dmc-wamp-rpc-callee](dmc-wamp-rpc-callee/): offers its own procedure, `com.example.multiply`, then calls it through the router like any other client would, and leaves:

```text
WAMP: Starting WAMP Communication
>> We have WAMP Join
WAMP: registered	com.example.multiply
WAMP: received INVOCATION	6	7
WAMP: successful RESULT
>>  data	42
>> We have WAMP Disconnect
```

The procedure returns its result as a plain value; it calls only once the router has confirmed the registration ([API reference](../docs/api.md#register)).

## Subscribe

[dmc-wamp-subscribe](dmc-wamp-subscribe/): subscribes to `com.myapp.topic1` and prints the backend's ticks (numbered from when the router started) for five seconds, unsubscribes, and leaves three seconds later:

```text
WAMP: Starting WAMP Communication
>> We have WAMP JOIN
WAMP: successful SUBSCRIBE
WAMP: received PUBLISH
Received: 	tick-76
WAMP: received PUBLISH
Received: 	tick-77
...
WAMP: received PUBLISH
Received: 	tick-80
WAMP: successful UNSUBSCRIBE
>> We have WAMP DISCONNECT
```

## Publish

[dmc-wamp-publish](dmc-wamp-publish/): publishes five messages on `com.myapp.topic1`, each after the router acknowledges the one before, then leaves:

```text
WAMP: Starting WAMP Communication
>> wampEvent_handler	wamp_on_connect_event
>> wampEvent_handler	wamp_on_join_event
>> We have WAMP Join
>> Wamp Publish event
>> WAMP publish acknowledgment
publish id: 4290550126906760
...
>> Wamp Publish event
>> WAMP publish acknowledgment
publish id: 5739908810836322
>> wampEvent_handler	wamp_on_disconnect_event
>> We have WAMP Disconnect
>> 	wamp.close.normal	nil
```

The router's log (`docker logs wamp-router`) shows the backend receiving them:

```text
[Container      28] backend: received event ('message-1',) {}
```

## Authentication

[dmc-wamp-authentication](dmc-wamp-authentication/): joins through the router's `/auth` path, which requires a login, answers the router's challenge, and calls `com.example.add2` with 2 and 10. Its `app_config.lua` chooses the user (`joe` with a plain secret, or `peter` with a salted one) and the method (`wampcra` or `ticket`); the [router README](router/README.md#users-on-auth) lists the users. It needs the Simulator: WAMP-CRA uses Solar2D's `crypto` library.

```text
WAMP: Starting WAMP Communication
>> WAMP onChallenge: 	wampcra
>> We have WAMP Join
>> WAMP:doWampRPC
WAMP: successful RESULT
>>  data	12
>>  results	1	12
>> We have WAMP Disconnect
>> 	wamp.close.normal	nil
```

With a wrong secret, the router refuses the login and the session ends before it's joined:

```text
>> WAMP onChallenge: 	wampcra
>> We have WAMP Disconnect
>> 	wamp.error.not_authorized	WAMP-CRA signature is invalid
```
