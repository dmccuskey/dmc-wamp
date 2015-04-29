--====================================================================--
-- WAMP Basic RPC
--
-- Caller RPC for the WAMP library
--
-- Sample code is MIT licensed, the same license which covers Lua itself
-- http://en.wikipedia.org/wiki/MIT_License
-- Copyright (C) 2014=2015 David McCuskey. All Rights Reserved.
--====================================================================--



print( '\n\n##############################################\n\n' )



--====================================================================--
--== Imports


-- read in app deployment configuration, global
_G.gINFO = require 'app_config'

local Wamp = require 'dmc_corona.dmc_wamp'
local Utils = require 'dmc_corona.dmc_utils'



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


local doWampRPC = function()
	-- print( ">> WAMP:doWampRPC" )

	local procedure = WAMP_RPC_PROCEDURE

	local callEvent_handler = function( event )
		-- print( ">> WAMP callEvent_handler", event.type )
		local etype = event.type

		if etype == Wamp.ONRESULT then
			print( "WAMP: successful RESULT" )

			if event.data then
				print( '>>  data', event.data )
			end
			if event.results then
				for i,v in ipairs( event.results ) do
					print( '>>  results', i, v )
				end
			end
			if event.kwresults then
				for k,v in pairs( event.kwresults ) do
					print( '>>  kwresults', k, v )
				end
			end

			-- close connection
			timer.performWithDelay( 2000, function() wamp:leave() end  )

		elseif etype == Wamp.ONPROGRESS then
			print( "WAMP: received PROGRESS" )

			-- if event.is_error then
			-- else
			-- end

		end

	end

	wamp:call( procedure, callEvent_handler, { args={2,2} } )

end



--====================================================================--
--== Main
--====================================================================--


local wampEvent_handler = function( event )
	-- print( ">> wampEvent_handler", event.type )

	if event.type == wamp.ONJOIN then
		print( ">> We have WAMP Join" )
		doWampRPC()

	elseif event.type == wamp.ONDISCONNECT then
		print( ">> We have WAMP Disconnect" )

	elseif event.type == wamp.ONERROR then
		print( ">> We have WAMP Error" )
		Utils.print( event )

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
