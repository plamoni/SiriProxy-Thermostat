require 'httparty'
require 'json'

class SiriProxy::Plugin::Thermostat < SiriProxy::Plugin
  attr_accessor :host

  def initialize(config = {})
    self.host = config["host"]
  end

  #capture thermostat status
  listen_for /thermostat.*status/i { show_status_of_thermostat }
  listen_for /status.*thermostat/i { show_status_of_thermostat }

  listen_for /thermostat.*([0-9]{2})/i { |temp| set_thermostat(temp) }

  listen_for /temperature.*inside/i { show_temperature }
  listen_for /inside.*temperature/i { show_temperature }
  listen_for /temperature.*in here/i { show_temperature }

  def show_status_of_thermostat
    say "Checking the status of the thermostat"
    
    Thread.new {
      page = HTTParty.get("http://#{self.host}/tstat").body rescue nil
      status = JSON.parse(page) rescue nil
      
      if status   
        say "The temperature is currently #{status["temp"]} degrees."
        
        if status["tmode"] == 0
          say "The heater and air conditioner are turned off." 
        else
          device_type = (status["tmode"] == 1 ? "heater" : "air conditioner")
                
          say "The #{device_type} is set to engage at #{status["t_heat"]} degrees."
          
          if status["tstate"] == 0
            say "The #{device_type} is off."
          elsif (status["tmode"] == 1 and status["tstate"] == 1) or (status["tmode"] == 2 and status["tstate"] == 2)
            say "The #{device_type} is running."
          end
        end
      else
        say "Sorry, the thermostat is off."
      end
    
      request_completed #always complete your request! Otherwise the phone will "spin" at the user!
    }
  end
   
  def set_thermostat(temp)
    say "One moment while I set the thermostat to #{temp} degrees."

    Thread.new {
      page = HTTParty.get("http://#{self.host}/tstat").body rescue nil
      status = JSON.parse(page) rescue nil
      
      if status
        device_type = (status["tmode"] == 1 ? "heater" : "air conditioner")
      
        status = HTTParty.post("http://#{self.host}/tstat", :body => {
                                                              :tmode  => status["tmode"],
                                                              :t_heat => temp.to_i
                                                            }.to_json)
                     
        if status["success"] == 0
          say "The #{device_type} has been set to #{temp} degrees."
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
      page = HTTParty.get("http://#{self.host}/tstat").body rescue nil
      status = JSON.parse(page) rescue nil
      
      if status
        say "The current inside temperature is #{status["temp"]} degrees."      
      else
        say "Sorry, the thermostat is off."
      end
        
      request_completed #always complete your request! Otherwise the phone will "spin" at the user!
    }
  end
end