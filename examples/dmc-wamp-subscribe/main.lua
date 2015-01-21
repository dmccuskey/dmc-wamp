--====================================================================--
-- WAMP Basic Publish/Subscribe
--
-- Basic Pub/Sub test for the WAMP library
--
-- by David McCuskey
--
-- Sample code is MIT licensed, the same license which covers Lua itself
-- http://en.wikipedia.org/wiki/MIT_License
-- Copyright (C) 2014 David McCuskey. All Rights Reserved.
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
local WAMP_PUBSUB_TOPIC = gINFO.server.pubsub_topic

local wamp -- ref to WAMP object



--====================================================================--
--== Support Functions


local doWampPubSub = function()
	-- print( ">> WAMP:doWampPubSub" )

	local topic = WAMP_PUBSUB_TOPIC

	local subscriptionEvent_handler = function( event )
		-- print( ">> WAMP PubSub::subscription Event handler", event.type )
		local etype = event.type

		if etype == Wamp.ONSUBSCRIBED then
			print( "WAMP: successful SUBSCRIBE" )

			-- if event.is_error then
			-- else
			-- end

		elseif etype == Wamp.ONPUBLISH then
			print( "WAMP: received PUBLISH" )

			if event.is_error then
				-- could be issue with subscription request
				-- or network close (maybe)
			else
				local args, kwargs = event.args, event.kwargs
				-- print( args, kwargs )
				print( "Received: ", args[1] )
			end

		elseif etype == Wamp.ONUNSUBSCRIBED then
			print( "WAMP: successful UNSUBSCRIBE" )

			-- if event.is_error then
			-- else
			-- end

		end

	end -- subscriptionEvent_handler

	-- subscribe to topic
	wamp:subscribe( topic, subscriptionEvent_handler )

	-- unsubscribe from topic
	local unsub = function( e )
		wamp:unsubscribe( topic, subscriptionEvent_handler )
	end
	timer.performWithDelay( 5000, unsub )

	-- close connection
	timer.performWithDelay( 8000, function(e) wamp:leave() end  )

end



--====================================================================--
--== Main
--====================================================================--


local wampEvent_handler = function( event )
	-- print( ">> wampEvent_handler", event.type )

	if event.type == wamp.ONJOIN then
		print( ">> We have WAMP JOIN" )
		doWampPubSub()

	elseif event.type == wamp.ONDISCONNECT then
		print( ">> We have WAMP DISCONNECT" )

	elseif event.type == wamp.ONERROR then
		print( ">> We have WAMP ERROR" )
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
