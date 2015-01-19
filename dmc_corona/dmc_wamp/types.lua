--====================================================================--
-- dmc_corona/dmc_wamp/types.lua
--
-- Documentation: http://docs.davidmccuskey.com/
--====================================================================--

--[[

The MIT License (MIT)

Copyright (c) 2014-2015 David McCuskey

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

--]]



--====================================================================--
--== DMC Corona Library : DMC WAMP Types
--====================================================================--


--[[
WAMP support adapted from:
* AutobahnPython (https://github.com/tavendo/AutobahnPython/)
--]]


-- Semantic Versioning Specification: http://semver.org/

local VERSION = "1.0.0"



--====================================================================--
--== Imports


local Objects = require 'dmc_objects'
local Utils = require 'dmc_utils'



--====================================================================--
--== Setup, Constants


-- setup some aliases to make code cleaner
local newClass = Objects.newClass
local ObjectBase = Objects.ObjectBase



--====================================================================--
--== Component Config Class
--====================================================================--


local ComponentConfig = newClass( ObjectBase, {name="Component Configuration"} )

function ComponentConfig:__init__( params )
	-- print( "ComponentConfig:__init__" )
	params = params or {}
	self:superCall( '__init__', params )
	--==--
	self.realm = params.realm
	self.extra = params.extra

	self.authid = params.authid
	self.authmethods = params.authmethods

	self.onchallenge = params.onchallenge

end



--====================================================================--
--== Router Options Class
--====================================================================--

-- not implemented



--====================================================================--
--== Hello Return Class
--====================================================================--


local HelloReturn = newClass( ObjectBase, {name="Hello Return Base"} )



--====================================================================--
--== Accept Class
--====================================================================--


local Accept = newClass( ObjectBase, {name="Accept"} )

function Accept:__init__( params )
	-- print( "Accept:__init__" )
	params = params or {}
	self:superCall( '__init__', params )
	--==--
	assert( params.authid == nil or type( params.authid ) == 'string' )
	assert( params.authrole == nil or type( params.authrole ) == 'string' )
	assert( params.authmethod == nil or type( params.authmethod ) == 'string' )
	assert( params.authprovider == nil or type( params.authprovider ) == 'string' )

	self.authid = params.authid
	self.authrole = params.authrole
	self.authmethod = params.authmethod
	self.authprovider = params.authprovider
end



--====================================================================--
--== Deny Class
--====================================================================--


local Deny = newClass( HelloReturn, {name="Deny"} )

function Deny:__init__( params )
	-- print( "Deny:__init__" )
	params = params or {}
	params.reason = params.reason or "wamp.error.not_authorized"
	self:superCall( '__init__', params )
	--==--
	assert( type( params.reason ) == 'string' )
	assert( params.message==nil or type( params.message )=='string' )

	self.reason = params.reason
	self.message = params.message
end



--====================================================================--
--== Challenge Class
--====================================================================--


local Challenge = newClass( HelloReturn, {name="Challenge"} )


function Challenge:__init__( params )
	-- print( "Challenge:__init__" )
	params = params or {}
	params.extra = params.extra or {}
	self:superCall( '__init__', params )
	--==--
	self.method = params.method
	self.extra = params.extra
end



--====================================================================--
--== Hello Details Class
--====================================================================--


local HelloDetails = newClass( HelloReturn, {name="Hello Details"} )

function HelloDetails:__init__( params )
	-- print( "HelloDetails:__init__" )
	params = params or {}
	self:superCall( '__init__', params )
	--==--
	self.roles = params.roles
	self.authmethods = params.authmethods
	self.authid = params.authid
	self.pending_session = params.pending_session
end



--====================================================================--
--== Session Details Class
--====================================================================--


local SessionDetails = newClass( HelloReturn, {name="Session Details"} )

function SessionDetails:__init__( params )
	-- print( "SessionDetails:__init__" )
	params = params or {}
	self:superCall( '__init__', params )
	--==--
	self.realm = params.realm
	self.session = params.session -- id
	self.authid = params.authid
	self.authrole = params.authrole
	self.authmethod = params.authmethod
	self.authprovider = params.authprovider
end



--====================================================================--
--== Close Details Class
--====================================================================--


local CloseDetails = newClass( ObjectBase, {name="Close Details"} )

function CloseDetails:__init__( params )
	-- print( "CloseDetails:__init__" )
	params = params or {}
	self:superCall( '__init__', params )
	--==--
	self.reason = params.reason
	self.message = params.message
end



--====================================================================--
--== Subscribe Options Class
--====================================================================--


local SubscribeOptions = newClass( ObjectBase, {name="Subscribe Options"} )

function SubscribeOptions:__init__( params )
	-- print( "SubscribeOptions:__init__" )
	params = params or {}
	self:superCall( '__init__', params )
	--==--
	assert( params.match==nil or ( type( params.match ) == 'string' and Utils.propertyIn( { 'exact', 'prefix', 'wildcard' }, params.match ) ) )
	assert( params.details_arg == nil or type( params.details_arg ) == 'string' )

	self.match = params.match
	self.details_arg = params.details_arg

	-- options dict as sent within WAMP message
	self.options = {match=match}
end



--====================================================================--
--== Register Options Class
--====================================================================--


local RegisterOptions = newClass( ObjectBase, {name="Register Options"} )

function RegisterOptions:__init__( params )
	-- print( "RegisterOptions:__init__" )
	params = params or {}
	self:superCall( '__init__', params )
	--==--
	self.details_arg = params.details_arg
	self.options = {
		pkeys=params.pkeys,
		disclose_caller=params.disclose_caller
	}
end



--====================================================================--
--== Call Details Class
--====================================================================--


local CallDetails = newClass( ObjectBase, {name="Call Details"} )

function CallDetails:__init__( params )
	-- print( "CallDetails:__init__" )
	params = params or {}
	self:superCall( '__init__', params )
	--==--
	self.progress = params.progress
	self.caller = params.caller
	self.authid = params.authid
	self.authrole = params.authrole
	self.authrole = params.authrole
end




--====================================================================--
--== Types Facade
--====================================================================--


return {
	ComponentConfig=ComponentConfig,
	-- Router Options,
	Accept=Accept,
	Deny=Deny,
	Challenge=Challenge,
	HelloDetails=HelloDetails,
	SessionDetails=SessionDetails,
	SubscribeOptions=SubscribeOptions,
	RegisterOptions=RegisterOptions,
	CallDetails=CallDetails,
	CloseDetails=CloseDetails,
}
