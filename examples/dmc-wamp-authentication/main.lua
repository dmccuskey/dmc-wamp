--====================================================================--
-- WAMP Basic Authentication
--
-- Example how to authenticate using the WAMP library
--
-- Sample code is MIT licensed, the same license which covers Lua itself
-- http://en.wikipedia.org/wiki/MIT_License
-- Copyright (C) 2014-2015 David McCuskey. All Rights Reserved.
--====================================================================--



print( "\n\n##############################################\n\n" )



--====================================================================--
--== Imports


-- read in app deployment configuration, global
_G.gINFO = require 'app_config'

local Wamp = require 'dmc_corona.dmc_wamp'
local Auth = require 'dmc_corona.dmc_wamp.auth'



--====================================================================--
--== Setup, Constants


-- WAMP server info in file 'app_config.lua'
--
local HOST = gINFO.server.host
local PORT = gINFO.server.port
local REALM = gINFO.server.realm
local WAMP_RPC_PROCEDURE = gINFO.server.remote_procedure

local wamp -- ref to WAMP object



--====================================================================--
--== Support Functions


local doWampRPC = function()
	print( ">> WAMP:doWampRPC" )

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

	local params = {
		args = { 2, 10 },
	}
	if wamp.is_connected then
		local deferred = wamp:call( procedure, callEvent_handler, params )
	end

	-- close connection
	timer.performWithDelay( 4000, function(e) wamp:leave() end  )

end



--====================================================================--
--== Main
--====================================================================--


local function onChallenge( event )
	print( ">> WAMP onChallenge: ", method )
	local session = event.session
	local method = event.method
	local extra = event.extra

	if method == Wamp.AUTH_WAMPCRA then
		return Auth.compute_wcs( gINFO.user.secret, extra.challenge )

	elseif method == Wamp.AUTH_TICKET then
		return gINFO.user.ticket

	else
		error( "Unknown auth method" .. tostring( method ) )
	end

	return
end


local wampEvent_handler = function( event )
	-- print( ">> wampEvent_handler", event.type )

	if event.type == wamp.ONJOIN then
		print( ">> We have WAMP Join" )
		doWampRPC()

	elseif event.type == wamp.ONDISCONNECT then
		print( ">> We have WAMP Disconnect" )
		print( ">> ", event.reason, event.message )
	end

end

print( "WAMP: Starting WAMP Communication" )

wamp = Wamp:new{
	uri=HOST,
	port=PORT,
	protocols={ 'wamp.2.json' },
	realm=REALM,
	user_id=gINFO.user.id,
	auth_methods=gINFO.server.authmethods,
	onChallenge=onChallenge
}
wamp:addEventListener( wamp.EVENT, wampEvent_handler )
