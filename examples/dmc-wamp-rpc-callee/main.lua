--====================================================================--
-- WAMP Basic RPC
--
-- Callee RPC for the WAMP library
--
-- Sample code is MIT licensed, the same license which covers Lua itself
-- http://en.wikipedia.org/wiki/MIT_License
-- Copyright (C) 2014-2015 David McCuskey. All Rights Reserved.
--====================================================================--



print( '\n\n##############################################\n\n' )



--====================================================================--
--== Imports


-- read in app deployment configuration, global
_G.gINFO = require 'app_config'

local Wamp = require 'dmc_corona.dmc_wamp'



--====================================================================--
--== Setup, Constants


-- WAMP server info in file 'app_config.lua'
--
local HOST = gINFO.server.host
local PORT = gINFO.server.port
local REALM = gINFO.server.realm
local WAMP_RPC_PROCEDURE = gINFO.server.rpc_procedure

local wamp -- ref to WAMP object



--====================================================================--
--== Support Functions


-- the procedure we offer to other WAMP clients
-- it gets the call's arguments as two tables, args (array) and kwargs
-- (dictionary), and returns its result
--
local multiply = function( args, kwargs )
	print( "WAMP: received INVOCATION", args[1], args[2] )
	return args[1] * args[2]
end


-- call our own procedure, as any other client could
--
local doWampRPC = function()

	local callEvent_handler = function( event )
		if event.type == Wamp.ONRESULT and event.is_error then
			print( "WAMP: call failed", event.error.error, event.error.message )

		elseif event.type == Wamp.ONRESULT then
			print( "WAMP: successful RESULT" )
			print( '>>  data', event.data )

			-- close connection
			timer.performWithDelay( 2000, function() wamp:leave() end  )
		end
	end

	wamp:call( WAMP_RPC_PROCEDURE, callEvent_handler, { args={6,7} } )

end



--====================================================================--
--== Main
--====================================================================--


local wampEvent_handler = function( event )
	-- print( ">> wampEvent_handler", event.type )

	if event.type == wamp.ONJOIN then
		print( ">> We have WAMP Join" )
		wamp:register( multiply, {
			procedure=WAMP_RPC_PROCEDURE,
			callback=function( event )
				if event.is_error then
					-- eg, wamp.error.procedure_already_exists
					print( "WAMP: register failed", event.error.error )
				else
					print( "WAMP: registered", WAMP_RPC_PROCEDURE )
					doWampRPC()
				end
			end
		} )

	elseif event.type == wamp.ONDISCONNECT then
		print( ">> We have WAMP Disconnect" )

	end

end

print( "WAMP: Starting WAMP Communication" )

wamp = Wamp:new{
	uri=HOST,
	port=PORT,
	protocols={ 'wamp.2.json' },
	realm=REALM
}
wamp:addEventListener( wamp.EVENT, wampEvent_handler )
