You can run this example by installing crossbar (http://crossbar.io/)


## Install Crossbar ##

* If you have `pip` on your computer (easier)

  https://github.com/crossbario/crossbar/wiki/Quick-Start

* Download the examples

  https://github.com/crossbario/crossbarexamples

  download the github examples on your computer (clone or zip).

  cd into `<location-of-examples>/authenticate/wampcra/`.

  _Note: you will start/stop `crossbar` in this directory._

* Update the crossbar config

  Located in this example, copy `crossbar-io/config.json` into the `.crossbar` folder

  Note, this config isn't entirely necessary, however it has both types of authentication ready for testing (eg, `ticket` and `secret` )

* Restart crossbar

	`crossbar -d start`


## Run Example ##

Once crossbar is running, you can launch the test application in Corona.

Update `app_config.lua` for your setup, eg, change IP address for your `crossbar` server.

