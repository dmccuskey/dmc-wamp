# dmc-wamp

A [WAMP](https://wamp-proto.org/) client for Solar2D (formerly Corona SDK) apps, written in Lua. WAMP (the Web Application Messaging Protocol) runs over WebSockets and gives an app two messaging patterns through one connection to a WAMP router: remote procedure calls and publish/subscribe.

Join a realm, call a procedure and subscribe to a topic:

```lua
local Wamp = require 'dmc_corona.dmc_wamp'

local wamp = Wamp{ uri='ws://127.0.0.1/ws', port=8080, realm='realm1' }

wamp:addEventListener( wamp.EVENT, function( event )
	if event.type == wamp.ONJOIN then
		wamp:call( 'com.example.add2', function( e ) print( 'sum:', e.data ) end, { args={ 2, 3 } } )
		wamp:subscribe( 'com.myapp.topic1', function( e )
			if e.type == Wamp.ONPUBLISH then print( 'event:', e.args[1] ) end
		end )
	end
end )
```

## Features

- WAMP v2 Basic Profile client: the Caller, Callee, Publisher and Subscriber roles
- JSON serialization (`wamp.2.json`)
- Authentication with WAMP-CRA (challenge-response) and tickets
- Event-based API that fits the Solar2D event loop; no threads or blocking calls
- Runs on [dmc-websockets](https://github.com/dmccuskey/dmc-websockets), so `wss://` works too
- A port of [AutobahnPython](https://github.com/crossbario/autobahn-python)'s WAMP code to Lua
- Pure Lua, MIT licensed

Not everything is there yet: no salted WAMP-CRA, MessagePack, or subscription and publish options. See [Known Issues](docs/api.md#known-issues).

## Quick Start

The following code will get you up and running in about 15 minutes in the Solar2D Simulator on macOS or Windows. It makes an app that joins a WAMP router running on your computer, calls a procedure and prints the events published on a topic.

Prerequisites: the [Solar2D](https://solar2d.com/) Simulator, [Docker](https://www.docker.com/) for the router, and a copy of this repository (`git clone https://github.com/dmccuskey/dmc-wamp.git`, or download the ZIP from GitHub).

1. **Start a WAMP router.** From this repository's folder, start [Crossbar.io](https://crossbar.io/) with the example setup in [`examples/router/`](examples/router/README.md). It provides the procedure `com.example.add2` and publishes `tick-1`, `tick-2`, ... on the topic `com.myapp.topic1` once a second:

   ```sh
   docker run --rm --name wamp-router -p 8080:8080 -v "$PWD/examples/router:/node" crossbario/crossbar
   ```

   It's ready when its log shows `Ok, node has started Container worker002` (the first start takes a minute or two, longer on Apple Silicon, where the image runs under emulation).

2. **Copy the library into your project.** From this repository, copy `dmc_corona/`, `dmc_corona_boot.lua` and `dmc_corona.cfg` into your project, at the root level of the project folder.

   **Going further:** keep libraries in a subfolder with [the `LUA_PATH` setting](https://github.com/dmccuskey/dmc-corona-boot/blob/master/docs/configuration.md#lua_path).

3. **Add the bit plugin.** Create `build.settings` (or add to yours) with the bit-operations plugin, which makes WebSocket framing fast:

   ```lua
   settings = {
   	plugins = {
   		["plugin.bit"] = { publisherId = "com.coronalabs" },
   	},
   }
   ```

   **Going further:** `wss://` needs `plugin.openssl` too, and Android the `INTERNET` permission; see [dmc-websockets' installation guide](https://github.com/dmccuskey/dmc-websockets/blob/master/docs/installation.md).

4. **Join the realm, call and subscribe.** Put this in `main.lua`:

   ```lua
   local Wamp = require 'dmc_corona.dmc_wamp'

   local wamp = Wamp{ uri='ws://127.0.0.1/ws', port=8080, realm='realm1' }

   local function onResult( event )
   	if event.is_error then
   		print( 'add2 failed:', event.error.error )
   	else
   		print( 'add2 result:', event.data )
   	end
   end

   local function onTopic( event )
   	if event.type == Wamp.ONSUBSCRIBED then
   		print( 'subscribed' )
   	elseif event.type == Wamp.ONPUBLISH then
   		print( 'received:', event.args[1] )
   	end
   end

   wamp:addEventListener( wamp.EVENT, function( event )
   	if event.type == wamp.ONJOIN then
   		print( 'joined realm1' )
   		wamp:call( 'com.example.add2', onResult, { args={ 2, 3 } } )
   		wamp:subscribe( 'com.myapp.topic1', onTopic )

   	elseif event.type == wamp.ONDISCONNECT then
   		print( 'disconnected:', event.reason, event.message )
   	end
   end )
   ```

5. **Run it** in the Simulator. The console shows:

   ```text
   joined realm1
   subscribed
   add2 result:	5
   received:	tick-19
   received:	tick-20
   received:	tick-21
   ...
   ```

   The two replies can arrive in either order, and the tick numbers count up from when the router started. If the router isn't running (`docker ps`), or the address or port is wrong, the console shows `disconnected:	wamp.close.transport_lost` instead. `add2 failed:	wamp.error.no_such_procedure` means the router's backend isn't running yet.

   **Going further:** offer your own procedures, publish, authenticate and leave the realm with the [API reference](docs/api.md) and the [examples](examples/README.md).

**Updating:** copy the same files again from a newer version of this repository.

## Documentation

- [API reference](docs/api.md): options, methods, events, authentication, configuration and known issues
- [Examples](examples/README.md): a caller, a callee, a publisher, a subscriber and an authenticated client, with a router to run them against
- [Development](docs/development.md): testing, rebuilding the bundled libraries
- [Changelog](CHANGELOG.md)

Everything else is on the [documentation home](docs/README.md).

## Acknowledgements

dmc-wamp is more or less a port of the WAMP code of [AutobahnPython](https://github.com/crossbario/autobahn-python) to Lua. Thanks to its authors.

## License

MIT, see [LICENSE](LICENSE). The bundled DMC libraries in `dmc_corona/` are MIT licensed too, except `dmc_corona/lib/sha1.lua` (from dmc-websockets): Jeffrey Friedl's pure-Lua SHA-1, whose header states his copyright but no license.
