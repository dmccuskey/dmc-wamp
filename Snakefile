# dmc-wamp

try:
	if not gSTARTED: print( gSTARTED )
except:
	MODULE = "dmc-wamp"
	include: "../DMC-Corona-Library/snakemake/Snakefile"

module_config = {
	"name": "dmc-wamp",
	"module": {
		"dir": "dmc_corona",
		"files": [
			"dmc_wamp.lua",
			"dmc_wamp/auth.lua",
			"dmc_wamp/exception.lua",
			"dmc_wamp/future_mix.lua",
			"dmc_wamp/message.lua",
			"dmc_wamp/protocol.lua",
			"dmc_wamp/role.lua",
			"dmc_wamp/serializer.lua",
			"dmc_wamp/types.lua",
			"dmc_wamp/utils.lua"
		],
		"requires": [
			"dmc-corona-boot",
			"DMC-Lua-Library",
			"dmc-websockets",
		]
	},
	"examples": {
		"base_dir": "examples",
		"apps": [
			{
				"exp_dir": "dmc-wamp-authentication",
				"requires": []
			},
			{
				"exp_dir": "dmc-wamp-publish",
				"requires": []
			},
			{
				"exp_dir": "dmc-wamp-rpc-callee",
				"requires": []
			},
			{
				"exp_dir": "dmc-wamp-rpc-caller",
				"requires": []
			},
			{
				"exp_dir": "dmc-wamp-subscribe",
				"requires": []
			}
		]
	},
	"tests": {
		"files": [],
		"requires": []
	}
}

register( "dmc-wamp", module_config )

