--====================================================================--
-- tests/dmc_wamp_class_spec.lua
--
-- unit tests for the Wamp class over a WebSocket connection, against a
-- stand-in for dmc_sockets and Solar2D's timer, Runtime and
-- system.getTimer, with WAMP messages as the router would send them
-- run with tests/run_unit.sh
--====================================================================--


module( ..., package.seeall )


--====================================================================--
--== Stand-ins


local timers = {}

local FakeSockets = {
	ATCP='atcp', OFF=0, LOW=1, MEDIUM=2, HIGH=3,
	throttle=nil,
	last=nil
}

function FakeSockets:create( stype, params )
	local sock = {
		CONNECT='connect_event', READ='read_event',
		CONNECTED='socket_connected', NOT_CONNECTED='socket_not_connected',
		sent={}, pending={}, closed=false
	}
	function sock:connect( host, port, handlers )
		self.host, self.port, self.handlers = host, port, handlers
	end
	function sock:send( data, callback )
		table.insert( self.sent, data )
	end
	function sock:receive( pattern, callback )
		local data = table.concat( self.pending )
		self.pending = {}
		callback{ data=data }
	end
	function sock:close()
		self.closed = true
	end
	FakeSockets.last = sock
	return sock
end


local json, bit, Wamp, ws_handshake



--====================================================================--
--== Helpers


-- a text frame as the router sends it: unmasked
--
local function serverFrame( data )
	local len = #data
	if len <= 125 then
		return string.char( 0x81, len ) .. data
	end
	return string.char( 0x81, 126, math.floor( len / 256 ), len % 256 ) .. data
end

-- a WAMP message as the client sent it: a masked text frame
--
local function decodeClientFrame( str )
	local b2 = str:byte( 2 )
	local len = bit.band( b2, 0x7f )
	local pos = 3
	if len == 126 then
		len = str:byte( 3 ) * 256 + str:byte( 4 )
		pos = 5
	end
	local mask = { str:byte( pos, pos + 3 ) }
	pos = pos + 4
	local out = {}
	for i = 1, len do
		out[i] = string.char( bit.bxor( str:byte( pos + i - 1 ), mask[ ( i - 1 ) % 4 + 1 ] ) )
	end
	return json.decode( table.concat( out ) )
end

local function feed( sock, wmsg )
	table.insert( sock.pending, serverFrame( json.encode( wmsg ) ) )
	sock.handlers.onData{ type=sock.READ }
end

-- the last WAMP message the client sent on the socket
--
local function lastSent( sock )
	return decodeClientFrame( sock.sent[ #sock.sent ] )
end

-- complete the TCP connection and the handshake, choosing WAMP
--
local function open( sock )
	sock.handlers.onConnect{ type=sock.CONNECT, status=sock.CONNECTED }
	local key = sock.sent[1]:match( 'Sec%-WebSocket%-Key: ([^\r]+)' )
	table.insert( sock.pending, 'HTTP/1.1 101 Switching Protocols\r\n'
		.. 'Upgrade: websocket\r\nConnection: Upgrade\r\n'
		.. 'Sec-WebSocket-Protocol: wamp.2.json\r\n'
		.. 'Sec-WebSocket-Accept: ' .. ws_handshake._buildServerKey( key ) .. '\r\n\r\n' )
	sock.handlers.onData{ type=sock.READ }
end

-- open the socket and join realm1 as session `id`
--
local function join( sock, id )
	open( sock )
	assert_equal( 1, lastSent( sock )[1], "HELLO" )
	feed( sock, { 2, id, {} } ) -- WELCOME
end

local function newWamp()
	local wamp = Wamp{ uri='ws://example.com/ws', realm='realm1' }
	local events = {}
	wamp:addEventListener( wamp.EVENT, function( event )
		table.insert( events, event.type )
	end )
	return wamp, FakeSockets.last, events
end

local function count( list, value )
	local n = 0
	for _, v in ipairs( list ) do
		if v == value then n = n + 1 end
	end
	return n
end

-- subscribe to `topic`, the router accepting it as subscription `sub_id`
--
local function subscribe( wamp, sock, topic, handler, sub_id )
	wamp:subscribe( topic, handler )
	local msg = lastSent( sock )
	assert_equal( 32, msg[1], "SUBSCRIBE" )
	feed( sock, { 33, msg[2], sub_id } ) -- SUBSCRIBED
end



--====================================================================--
--== Setup


function suite_setup()
	system.getTimer = function() return 0 end
	_G.timer = {
		performWithDelay=function( ms, f )
			local t = { ms=ms, f=f }
			table.insert( timers, t )
			return t
		end,
		cancel=function( t ) t.cancelled = true end
	}
	_G.Runtime = {
		addEventListener=function() end,
		removeEventListener=function() end
	}
	package.loaded[ 'dmc_sockets' ] = FakeSockets

	require 'dmc_corona_boot'
	json = require 'json'
	bit = require 'lib.dmc_lua.bit'
	Wamp = require 'dmc_wamp'
	ws_handshake = require 'dmc_websockets.handshake'
end

function setup()
	timers = {}
end



--====================================================================--
--== Tests


function test_join()
	local wamp, sock, events = newWamp()
	join( sock, 11 )
	assert_true( wamp.is_connected )
	assert_equal( 1, count( events, wamp.ONCONNECT ) )
	assert_equal( 1, count( events, wamp.ONJOIN ) )
end


--== Connecting again

-- connect() on a closed Wamp: a new connection and session, the same
-- object and listeners
--
function test_reconnectJoinsAgain()
	local wamp, sock1, events = newWamp()
	join( sock1, 11 )
	sock1.handlers.onConnect{ type=sock1.CONNECT, status=sock1.NOT_CONNECTED } -- dropped
	assert_false( wamp.is_connected )
	assert_equal( 1, count( events, wamp.ONDISCONNECT ) )

	wamp:connect()
	local sock2 = FakeSockets.last
	assert_not_equal( sock1, sock2 )
	join( sock2, 22 )
	assert_true( wamp.is_connected )
	assert_equal( 22, wamp._session._session_id )
	assert_equal( 2, count( events, wamp.ONCONNECT ) )
	assert_equal( 2, count( events, wamp.ONJOIN ) )

	-- dropped again: one more ONDISCONNECT
	sock2.handlers.onConnect{ type=sock2.CONNECT, status=sock2.NOT_CONNECTED }
	assert_equal( 2, count( events, wamp.ONDISCONNECT ) )
end

-- the router forgets subscriptions with the session: so does the object
--
function test_reconnectForgetsSubscriptions()
	local wamp, sock1 = newWamp()
	join( sock1, 11 )
	local handler = function() end
	subscribe( wamp, sock1, 'com.topic', handler, 101 )
	sock1.handlers.onConnect{ type=sock1.CONNECT, status=sock1.NOT_CONNECTED }

	wamp:connect()
	local sock2 = FakeSockets.last
	join( sock2, 22 )
	local ok, err = pcall( wamp.unsubscribe, wamp, 'com.topic', handler )
	assert_false( ok, "the old subscription is gone" )
	assert_match( 'handler not found', err )

	-- subscribed again: unsubscribe() uses the new subscription
	subscribe( wamp, sock2, 'com.topic', handler, 202 )
	wamp:unsubscribe( 'com.topic', handler )
	local msg = lastSent( sock2 )
	assert_equal( 34, msg[1], "UNSUBSCRIBE" )
	assert_equal( 202, msg[3] )
end
