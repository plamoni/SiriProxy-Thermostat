Siri Proxy
==========

About
-----
SiriProxy-Thermostat is a SiriProxy plugin for controlling a [RadioThermostat](radiothermostat.com) thermostat.

Word of Warning
---------------
Please be aware that programs that interact with your thermostat have the inherent dangers of causing errant temperatures, high energy usage, or even possibly mechanical problems should the software fail to perform as expected.  

Installation
------------
After installing and configuring SiriProxy you can modify the `~/.siriproxy/config.yml` file:

	- name: 'Thermostat'
	git: 'git://github.com/plamoni/SiriProxy-Thermostat.git'
	# One thermostat
	thermostats: { "": "192.168.0.101" }
	# Two or more thermostats
	#thermostats: { 'upstairs': '192.168.0.101', 'downstairs': '192.168.0.102' }

	# Optional settings for 'away'.  Values indicated are the preset defaults
	#away_heat: 55
	#away_cool: 86
Be sure to replace the 192.168.0.101 and 192.168.0.102 addresses with the correct address(es) for your home.  Note that you can spefify multiple thermostats by adding a comma and then one, or more, entries for additional thermostats.  The away_heat and away_cool values are for energy savings if you set the thermostat to away

Usage
-----
The following voice commands are supported.  The name 'upstairs', as assigned in the example configuration, and the temperature of 65 degrees are only used for examples:

**Hold current temperature until manually changed**

    Hold temperature
    Hold current temperature
    Hold upstairs temperature

**Remove temperature hold**

Returns to temperature set in schedule

    Remove temperature hold
    Remove hold on temperature
    Remove hold on upstairs temperature

**Check thermostat status**

Get temperature, Setpoint, and if unit is running

    Thermostat status
    Status of upstairs thermostat

**Set the temperature**

Will be reset by a schedule change unless hold is set (see above)

    Set the temperature to 65 degrees
    Set the upstairs temperature to 65 degrees

**Get the temperature**

Must say 'inside', otherwise Siri defaults to telling you the weather
If you do say 'inside' and Siri reports it is raining you may need to call a plumber

    What is the temperature inside
    What is the temperature upstairs

**Set 'away'**

As seen in RadioThermostat App.  To save energy, the 'away' status will lower/raise the temperature, based on heating or cooling status, of ALL thermostats.  You will need to cancel the away status or hold(s) for the thermostat to return to normal operation.  

    Set thermostat to away
    
This has been manually implemented, if anyone knows of an API setting for this then please share.  Setting to 'away' via SiriProxy does not show as being set to 'away' in the RadioThermostat iPhone App.


**Return from 'away'**

Remove the 'away' status as indicated above.  This will remove holds placed on ALL configured thermostats.

     Set thermostat to normal

License (MIT)
-------------

SiriProxy-Thermostat - A plugin for SiriProxy
Copyright (c) 2013 Pete Lamonica

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
