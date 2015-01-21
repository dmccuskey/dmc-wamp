--====================================================================--
-- WAMP Basic Publish
--
-- Basic Publish test for the WAMP library
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
local WAMP_PUBSUB_TOPIC = gINFO.server.pubsub_topic

local wamp -- ref to WAMP object
local doWampPublish -- forward delare function

-- config for message count
local num_msgs = 5
local count = 0



--====================================================================--
--== Support Functions


doWampPublish = function()
	print( ">> Wamp Publish event")

	local topic = WAMP_PUBSUB_TOPIC

	local publish_handler = function( publication )
		print( ">> WAMP publish acknowledgment" )

		print( string.format( "publish id: %d", publication.id ) )

		if count == num_msgs then
			-- wamp:close()
		else
			timer.performWithDelay( 500, function() doWampPublish() end )
		end
	end

	count = count + 1
	local params = {
		args={ "message-" .. tostring(i), },
		-- kwargs={},
		callback=publish_handler
	}
	wamp:publish( topic, params )

end



--====================================================================--
--== Main
--====================================================================--


local wampEvent_handler = function( event )
	print( ">> wampEvent_handler", event.type )

	if event.type == wamp.ONJOIN then
		print( ">> We have WAMP Join" )
		doWampPublish()

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
	realm=REALM
}
wamp:addEventListener( wamp.EVENT, wampEvent_handler )
