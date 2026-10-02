--====================================================================--
-- tests/dmc_wamp_spec.lua
--
-- unit tests for dmc_wamp: messages, and a session driven through a
-- stand-in transport, with WAMP messages as the router would send them
-- run with tests/run_unit.sh
--====================================================================--


module( ..., package.seeall )


--====================================================================--
--== Setup


local json, WError, WMessage, WProtocol, WTypes
local serializer

function suite_setup()
	require 'dmc_corona_boot'
	json = require 'json'
	WError = require 'dmc_wamp.exception'
	WMessage = require 'dmc_wamp.message'
	WProtocol = require 'dmc_wamp.protocol'
	WTypes = require 'dmc_wamp.types'
	serializer = require( 'dmc_wamp.serializer' ).create( 'json' )
end


-- a message as the router sends it, eg { 8, 48, 7, {}, 'wamp.error.x' }
--
local function fromWire( wmsg )
	return serializer:unserialize( json.encode( wmsg ) )
end

-- a message as it goes out on the wire
--
local function toWire( msg )
	return json.decode( ( serializer:serialize( msg ) ) )
end

-- stand-in transport: keeps what the session sends
--
local function newTransport()
	local t = { sent={}, closed=false }
	function t:send( msg ) table.insert( self.sent, msg ) end
	function t:close() self.closed = true end
	function t:last() return self.sent[ #self.sent ] end
	return t
end

-- a session joined to realm1, with session id 1
--
local function newSession( config )
	local s = WProtocol.Session{ config=config }
	local t = newTransport()
	s:onOpen{ transport=t }
	s:onMessage( fromWire{ 2, 1, {} } ) -- WELCOME
	return s, t
end

-- the request id of the last message sent
--
local function lastRequest( t )
	return t:last().request
end

-- callbacks that record the outcome of a future
--
local function watch( def )
	local out = {}
	def:addCallbacks(
		function( v ) out.ok = true ; out.value = v end,
		function( e ) out.ok = false ; out.err = e end
	)
	return out
end



--====================================================================--
--== Messages


function test_errorParse()
	local msg = fromWire{ 8, 48, 7, {}, 'wamp.error.no_such_procedure', { 'nope' }, { a=1 } }
	assert_equal( 48, msg.request_type )
	assert_equal( 7, msg.request )
	assert_equal( 'wamp.error.no_such_procedure', msg.error )
	assert_equal( 'nope', msg.args[1] )
	assert_equal( 1, msg.kwargs.a )

	msg = fromWire{ 8, 64, 9, {}, 'wamp.error.procedure_already_exists' }
	assert_equal( 9, msg.request )
	assert_nil( msg.args )
	assert_nil( msg.kwargs )
end

function test_errorMarshal()
	local msg = WMessage.Error:new{ request_type=68, request=5, error='wamp.error.runtime_error', args={ 'boom' } }
	local w = toWire( msg )
	assert_equal( 8, w[1] )
	assert_equal( 68, w[2] )
	assert_equal( 5, w[3] )
	assert_equal( 'wamp.error.runtime_error', w[5] )
	assert_equal( 'boom', w[6][1] )
end

function test_invocationTimeout()
	-- the router passes a call's timeout on to the callee, in ms
	local msg = fromWire{ 68, 3, 4, { timeout=1000 }, { 1 } }
	assert_equal( 1000, msg.timeout )
end

function test_goodbyeDefaultReason()
	local msg = WMessage.Goodbye:new()
	assert_equal( WMessage.Goodbye.DEFAULT_REASON, msg.reason )
end

function test_applicationError()
	local e = WError.ApplicationError{ error='com.example.oops', args={ 'bad input' } }
	assert_equal( 'com.example.oops', e.error )
	assert_equal( 'bad input', e.message )
	assert_true( e:isa( WError.ApplicationError ) )

	e = WError.ApplicationError{ error='com.example.oops' }
	assert_equal( 'com.example.oops', e.message )
end

function test_protocolError()
	local e = WError.ProtocolError( "bad message" )
	assert_equal( "bad message", e.message )
	assert_equal( "bad message", e.reason )
	e = WError.TransportLost()
	assert_equal( "WAMP transport lost", e.message )
end



--====================================================================--
--== Session: Errors


function test_callError()
	local s, t = newSession()
	local out = watch( s:call( 'com.example.missing', {} ) )
	s:onMessage( fromWire{ 8, 48, lastRequest( t ), {}, 'wamp.error.no_such_procedure', { 'no callee' } } )
	assert_false( out.ok )
	assert_true( out.err:isa( WError.ApplicationError ) )
	assert_equal( 'wamp.error.no_such_procedure', out.err.error )
	assert_equal( 'no callee', out.err.message )
	assert_nil( next( s._call_reqs ) )
end

function test_subscribeError()
	local s, t = newSession()
	local out = watch( s:subscribe( 'com.topic', function() end ) )
	s:onMessage( fromWire{ 8, 32, lastRequest( t ), {}, 'wamp.error.not_authorized' } )
	assert_false( out.ok )
	assert_equal( 'wamp.error.not_authorized', out.err.error )
end

function test_errorForUnknownRequest()
	local s = newSession()
	assert_error( function()
		s:onMessage( fromWire{ 8, 48, 12345, {}, 'wamp.error.no_such_procedure' } )
	end )
end



--====================================================================--
--== Session: Publish and Call Options


function test_publishAcknowledge()
	local s, t = newSession()
	local def = s:publish( 'com.topic', { args={ 1 }, options={ acknowledge=true } } )
	assert_not_nil( def )
	assert_true( toWire( t:last() )[3].acknowledge )

	local out = watch( def )
	s:onMessage( fromWire{ 17, lastRequest( t ), 4242 } )
	assert_true( out.ok )
	assert_equal( 4242, out.value.id )
end

function test_publishNoAcknowledge()
	local s, t = newSession()
	assert_nil( s:publish( 'com.topic', { args={ 1 } } ) )
	assert_nil( toWire( t:last() )[3].acknowledge )
	assert_nil( next( s._publish_reqs ) )
end

function test_publishError()
	local s, t = newSession()
	local out = watch( s:publish( 'com.topic', { options={ acknowledge=true } } ) )
	s:onMessage( fromWire{ 8, 16, lastRequest( t ), {}, 'wamp.error.not_authorized' } )
	assert_false( out.ok )
	assert_equal( 'wamp.error.not_authorized', out.err.error )
end

function test_callOptions()
	local s, t = newSession()
	s:call( 'com.proc', { options={ timeout=500, receive_progress=true } } )
	local opts = toWire( t:last() )[3]
	assert_equal( 500, opts.timeout )
	assert_true( opts.receive_progress )

	-- a CallOptions object too
	s:call( 'com.proc', { options=WTypes.CallOptions{ timeout=100, onProgress=function() end } } )
	opts = toWire( t:last() )[3]
	assert_equal( 100, opts.timeout )
	assert_true( opts.receive_progress )
end

function test_callProgress()
	local s, t = newSession()
	local progress = {}
	local out = watch( s:call( 'com.proc', { options={ receive_progress=true, onProgress=function( args ) table.insert( progress, args[1] ) end } } ) )
	local req = lastRequest( t )
	s:onMessage( fromWire{ 50, req, { progress=true }, { 'half' } } )
	assert_equal( 'half', progress[1] )
	assert_nil( out.ok )
	s:onMessage( fromWire{ 50, req, {}, { 'done' } } )
	assert_true( out.ok )
	assert_equal( 'done', out.value.results[1] )
end



--====================================================================--
--== Session: Register and Unregister


local function registerFn( s, t, fn, procedure )
	local out = watch( s:register( fn, { procedure=procedure or 'com.proc' } ) )
	s:onMessage( fromWire{ 65, lastRequest( t ), 77 } )
	return out
end

function test_registerAccepted()
	local s, t = newSession()
	local out = registerFn( s, t, function() end )
	assert_true( out.ok )
	assert_equal( 77, out.value.id )
	assert_not_nil( s._registrations[ 77 ] )
end

function test_registerRefused()
	local s, t = newSession()
	local out = watch( s:register( function() end, { procedure='com.proc' } ) )
	s:onMessage( fromWire{ 8, 64, lastRequest( t ), {}, 'wamp.error.procedure_already_exists' } )
	assert_false( out.ok )
	assert_equal( 'wamp.error.procedure_already_exists', out.err.error )
end

function test_registerOptions()
	local s, t = newSession()
	s:register( function() end, { procedure='com.proc', options=WTypes.RegisterOptions{ disclose_caller=true } } )
	assert_true( toWire( t:last() )[3].disclose_caller )
end

function test_unregister()
	local s, t = newSession()
	local fn = function() end
	registerFn( s, t, fn )

	local out = watch( s:unregister( fn ) )
	local msg = t:last()
	assert_true( msg:isa( WMessage.Unregister ) )
	assert_equal( 77, msg.registration )

	s:onMessage( fromWire{ 67, msg.request } )
	assert_true( out.ok )
	assert_nil( s._registrations[ 77 ] )
end

function test_unregisterUnknown()
	local s = newSession()
	assert_error( function() s:unregister( function() end ) end )
end



--====================================================================--
--== Session: Invocations


-- invokes procedure `fn`, returns what the session sent back
--
local function invoke( fn, args, obj )
	local s, t = newSession()
	if obj then
		s._register_reqs[ 1 ] = { s:_create_future(), obj, fn, 'com.proc', {} }
		s:onMessage( fromWire{ 65, 1, 77 } )
	else
		registerFn( s, t, fn )
	end
	s:onMessage( fromWire{ 68, 500, 77, {}, args or {} } )
	local reply = t:last()
	assert_equal( 500, reply.request )
	assert_nil( s._invocations[ 500 ] )
	return reply
end

function test_invocationPlainValue()
	local reply = invoke( function( args ) return args[1] + args[2] end, { 2, 3 } )
	assert_true( reply:isa( WMessage.Yield ) )
	assert_equal( 5, reply.args[1] )
end

function test_invocationNothing()
	local reply = invoke( function() end )
	assert_true( reply:isa( WMessage.Yield ) )
	assert_nil( reply.args )
end

function test_invocationResultsTable()
	local reply = invoke( function() return { results={ 1, 2 }, kwresults={ a=3 } } end )
	assert_equal( 2, #reply.args )
	assert_equal( 3, reply.kwargs.a )

	-- any other table is the single result
	reply = invoke( function() return { x=1 } end )
	assert_equal( 1, reply.args[1].x )
end

function test_invocationObject()
	local obj = { k=10 }
	local reply = invoke( function( self, args ) return self.k * args[1] end, { 4 }, obj )
	assert_equal( 40, reply.args[1] )
end

function test_invocationRaises()
	local _print = _G.print ; _G.print = function() end
	local reply = invoke( function() error( 'boom!' ) end )
	_G.print = _print
	assert_true( reply:isa( WMessage.Error ) )
	assert_equal( WMessage.Invocation.MESSAGE_TYPE, reply.request_type )
	assert_equal( 'wamp.error.runtime_error', reply.error )
	assert_match( 'boom!', reply.args[1] )
end

function test_invocationApplicationError()
	local reply = invoke( function()
		error( WError.ApplicationError{ error='com.example.invalid', args={ 'bad' } } )
	end )
	assert_true( reply:isa( WMessage.Error ) )
	assert_equal( 'com.example.invalid', reply.error )
	assert_equal( 'bad', reply.args[1] )
end



--====================================================================--
--== Session: Leaving and Lost Connections


function test_transportLostWhileJoined()
	local s, t = newSession()
	local out = watch( s:call( 'com.proc', {} ) )
	s:onClose( "Network Error" )
	assert_nil( s._session_id )
	assert_equal( 'wamp.close.transport_lost', s._close_details.reason )
	assert_equal( 'Network Error', s._close_details.message )
	assert_false( out.ok )
	assert_true( out.err:isa( WError.TransportLost ) )
	-- nothing left to close
	s:disconnect()
end

function test_routerGoodbye()
	local s, t = newSession()
	s:onMessage( fromWire{ 6, { message='shutting down' }, 'wamp.close.system_shutdown' } )
	assert_true( t:last():isa( WMessage.Goodbye ) )
	assert_equal( 'wamp.close.goodbye_and_out', t:last().reason )
	assert_true( t.closed )
	assert_nil( s._session_id )
	assert_equal( 'wamp.close.system_shutdown', s._close_details.reason )
	assert_equal( 'shutting down', s._close_details.message )
end

function test_leave()
	local s, t = newSession()
	s:leave{ reason='wamp.close.normal', message='bye' }
	assert_equal( 'wamp.close.normal', t:last().reason )
	assert_equal( 'bye', t:last().message )
	s:onMessage( fromWire{ 6, {}, 'wamp.close.goodbye_and_out' } )
	assert_true( t.closed )
	assert_equal( 2, #t.sent ) -- HELLO, GOODBYE: no second GOODBYE
end

function test_abort()
	local s = WProtocol.Session{}
	local t = newTransport()
	s:onOpen{ transport=t }
	s:onMessage( fromWire{ 3, { message='no such realm' }, 'wamp.error.no_such_realm' } )
	assert_true( t.closed )
	assert_equal( 'wamp.error.no_such_realm', s._close_details.reason )
end



--====================================================================--
--== Session: Challenge


function test_challenge()
	local cfg = WTypes.ComponentConfig{
		realm='realm1', authid='joe', authmethods={ 'ticket' },
		onchallenge=function( args ) return 'secret-' .. args[1].method end
	}
	local s = WProtocol.Session{ config=cfg }
	local t = newTransport()
	local seen
	s:addEventListener( s.EVENT, function( e )
		if e.type == s.ONCHALLENGE then seen = e.challenge.method end
	end )
	s:onOpen{ transport=t }
	s:onMessage( fromWire{ 4, 'ticket', {} } )
	assert_equal( 'ticket', seen )
	assert_true( t:last():isa( WMessage.Authenticate ) )
	assert_equal( 'secret-ticket', t:last().signature )
end
