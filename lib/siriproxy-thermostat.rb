require 'httparty'
require 'json'

#######
# This is a "hello world" style plugin. It simply intercepts the phrase "text siri proxy" and responds
# with a message about the proxy being up and running (along with a couple other core features). This 
# is good base code for other plugins.
# 
# Remember to add other plugins to the "config.yml" file if you create them!
######

class SiriProxy::Plugin::Thermostat < SiriProxy::Plugin
  attr_accessor :host

  def initialize(config)
    self.host = config["host"]
  end

  #capture thermostat status
  listen_for /thermostat.*status/i do show_status_of_thermostat end
  listen_for /status.*thermostat/i do show_status_of_thermostat end

  listen_for /thermostat.*([0-9]{2})/i do |temp| set_thermostat(temp) end

  listen_for /temperature.*inside/i do show_temperature end
  listen_for /inside.*temperature/i do show_temperature end
  listen_for /temperature.*in here/i do show_temperature end

  def show_status_of_thermostat
    say "Checking the status of the thermostat"
    
    Thread.new {
      status = JSON.parse(HTTParty.get("http://#{self.host}/tstat").body)
         
      say "The temperature is currently #{status["temp"]} degrees."
      say "The heater and air conditioner are turned off." if(status["tmode"] == 0)
             
      if(status["tmode"] == 1)
        say "The heater is set to engage at #{status["t_heat"]} degrees."
        say "The heater is off." if(status["tstate"] == 0)
        say "The heater is running." if(status["tstate"] == 1)
      elsif(status["tmode"] == 2)
        say "The air conditioner is set to engage at #{status["t_cool"]} degrees."
        say "The air conditioner is off." if(status["tstate"] == 0)
        say "The air conditioner running." if(status["tstate"] == 2)
      end
    
      request_completed #always complete your request! Otherwise the phone will "spin" at the user!
    }
  end
   
  def set_thermostat(temp)
    say "One moment while I set the thermostat to #{temp} degrees"

    Thread.new {
      status = JSON.parse(HTTParty.get("http://#{self.host}/tstat").body)
      if(status["tmode"] == 1) #heat
        status = HTTParty.post("http://#{self.host}/tstat", {:body => "{\"tmode\":1,\"t_heat\":#{temp.to_i}}"})
                     
        if(status["success"] == 0)
          say "The heater has been set to #{temp} degrees."
        else
          say "Sorry, there was a problem setting the temperature"
        end
      elsif(status["tmode"] == 2) #a/c
        status = HTTParty.post("http://#{self.host}/tstat", {:body => "{\"tmode\":2,\"t_cool\":#{temp.to_i}}"})
                
        if(status["success"] == 0)
          say "The air conditioner has been set to #{temp} degrees."
        else
          say "Sorry, there was a problem setting the temperature"
        end
      else
        say "Sorry, the thermostat is off."
      end
        
      request_completed #always complete your request! Otherwise the phone will "spin" at the user!
    }    
  end
  
  def show_temperature
    say "Checking the inside temperature."
    
    Thread.new {
      status = JSON.parse(HTTParty.get("http://#{self.host}/tstat").body)
        say "The current inside temperature is #{status["temp"]} degrees."      
      }

  end
end