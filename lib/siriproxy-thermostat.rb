require 'httparty'
require 'json'

class SiriProxy::Plugin::Thermostat < SiriProxy::Plugin
  attr_accessor :thermostats
  attr_accessor :thermostat_name
  attr_accessor :thermostat
  attr_accessor :away_heat
  attr_accessor :away_cool

  def initialize(config = {})
    # Create an initial hash to add to later
    self.thermostats = Hash.new

    # Support legacy syntax for folks that don't update their config
    if config.has_key?("host")
      # Need a placeholder name 
      self.thermostats = self.thermostats.merge({ "" => config["host"]})
    end

    # Get hash of thermostats from config if available
    if config.has_key?("thermostats")
      self.thermostats = self.thermostats.merge(config["thermostats"])
    end

    # Select the first configured thermostat by default
    self.thermostat_name = self.thermostats.keys.first
    self.thermostat = self.thermostats[thermostat_name]

    # Set value for minimum temperature when "away"
    if config.has_key?("away_heat")
      self.away_heat = config["away_heat"]
    else
      self.away_heat = "55"
    end

    # Set value for maximum temperature when "away"
    if config.has_key?("away_cool")
      self.away_cool = config["away_cool"]
    else
      self.away_cool = "86"
    end
  end

  def at_exit
    # issuing exit does not work without an at_exit?!
  end

  # Adding this because I noticed it the selection persistes for a short time
  # Could add long term states for this, but I prefer addressing the thermostat by name
  listen_for(/use.* ([A-Za-z]+) thermostat/i) { |thermostat_name| set_current_thermostat(thermostat_name) }
  listen_for(/set.*(current|default).*thermostat.* ([A-Za-z]+) /i) { |ignore,thermostat_name| set_current_thermostat(thermostat_name) }

  # Hold currently set temperature indefinately
  listen_for(/remove.*h*old.* ([A-Za-z]+) temperature/i) { |thermostat_name| remove_hold(thermostat_name) }
  listen_for(/remove.*h*old.*temperature/i) { remove_hold("") }
  listen_for(/remove.*temperature*.*h*old/i) { remove_hold("") }

  # Remove temperature hold
  listen_for(/h*old.* ([A-Za-z]+) temperature/i) { |thermostat_name| set_hold(thermostat_name) }
  listen_for(/h*old.*temperature ([A-Za-z])+/i) { |thermostat_name| set_hold(thermostat_name) }
  listen_for(/h*old.*temperature/i) { set_hold("") }

  # Capture thermostat status
  listen_for(/([A-Za-z]+) thermostat.*status/i) { |thermostat_name| show_status_of_thermostat(thermostat_name) }
  listen_for(/status.* ([A-Za-z]+) thermostat/i) { |thermostat_name| show_status_of_thermostat(thermostat_name) }
  listen_for(/thermostat.*status/i) { show_status_of_thermostat("") }
  listen_for(/status.*thermostat/i) { show_status_of_thermostat("") }

  # Set temperature for thermostat
  listen_for(/([A-Za-z]+)* (?:temperature|thermostat).*([0-9]{2})/i) { |thermostat_name,temp| set_thermostat(thermostat_name,temp) }
  listen_for(/(?:temperature|thermostat) ([A-Za-z]+).*([0-9]{2})/i) { |thermostat_name,temp| set_thermostat(thermostat_name,temp) }

  # Check temperature reported by thermostat
  listen_for(/temperature ([A-Za-z]+)/i) { |thermostat_name| show_temperature(thermostat_name) }
  listen_for(/([A-Za-z]+) temperature/i) { |thermostat_name| show_temperature(thermostat_name) }
  listen_for(/temperature.*inside/i) { show_temperature("") }
  listen_for(/inside.*temperature/i) { show_temperature("") }
  listen_for(/temperature.*here/i) { show_temperature("") }

  # Trigger "away" status
  listen_for(/thermostats*.*away/i) { set_thermostats_away }

  # Unset "away" status
  listen_for(/thermostats*.*(back|home|normal)/i) { set_thermostats_back }

  def get_thermostat_by_name(thermostat_name)
    # Normalize thermostat_name
    thermostat_name=thermostat_name.downcase

    puts "[Info - Thermostat Name] \"#{thermostat_name}\" requested"
    
    # Sanity Check
    if self.thermostats.length < 1
      say "Sorry, no thermostats defined"
      request_completed #always complete your request! Otherwise the phone will "spin" at the user!
      exit 0
    end

    # Test defined thermostats for a name match
    match_found=false
    self.thermostats.each do |key,value|
      if thermostat_name =~/[^A-Za-z]/
        say "You have configured a thermostat with a bad name"
      end

      if thermostat_name == key.downcase
        self.thermostat_name = key
	self.thermostat = value
        match_found=true
        break
      end
    end

    # Sanitize name to eliminate placeholder for legacy config
    if self.thermostat_name == " "
        self.thermostat_name=""
    end

    puts "[Info - Thermostat Name] \"#{self.thermostat_name}\" selected, using \"#{self.thermostat}\""
  end

  def set_current_thermostat(thermostat_name)
    get_thermostat_by_name(thermostat_name)
    say "Now using #{thermostat_name} thermostat by default"
    request_completed #always complete your request! Otherwise the phone will "spin" at the user!
  end

  def show_status_of_thermostat(thermostat_name)
    get_thermostat_by_name(thermostat_name)
    say "Checking the status of the #{self.thermostat_name} thermostat"
    
    Thread.new {
      page = HTTParty.get("http://#{self.thermostat}/tstat").body rescue nil
      status = JSON.parse(page) rescue nil
      
      if status   
        say "The temperature is currently #{status["temp"]} degrees."
        
        if status["tmode"] == 0
          say "The heater and air conditioner are turned off." 
        else
          device_type = (status["tmode"] == 1 ? "heater" : "air conditioner")
                
          say "The #{device_type} is set to " + (status["hold"] == 0 ? "engage" : "hold") + " at #{status["t_heat"]} degrees."
          
	  # Check to see if fan is set to 'on' instead of 'auto'
	  if status["fmode"] == 2
	    fan_status="  The fan is set to run continuously."
	  else
	    fan_status=""
	  end

          if status["tstate"] == 0
            say "The #{device_type} is off.#{fan_status}"
          elsif (status["tmode"] == 1 and status["tstate"] == 1) or (status["tmode"] == 2 and status["tstate"] == 2)
            say "The #{device_type} is running.#{fan_status}"
          end
        end
      else
        say "Sorry, the thermostat is unreachable."
      end
    
      request_completed #always complete your request! Otherwise the phone will "spin" at the user!
    }
  end
   
  def set_thermostat(thermostat_name,temp)
    get_thermostat_by_name(thermostat_name)
    say "One moment while I set the #{self.thermostat_name} thermostat to #{temp} degrees."

    Thread.new {
      page = HTTParty.get("http://#{self.thermostat}/tstat").body rescue nil
      status = JSON.parse(page) rescue nil
      
      if status
        device_type = (status["tmode"] == 1 ? "heater" : "air conditioner")
      
        status = HTTParty.post("http://#{self.thermostat}/tstat", :body => {
                                                              :tmode  => status["tmode"],
                                                              :t_heat => temp.to_i
                                                            }.to_json)
                     
        if status["success"] == 0
          say "The #{device_type} has been set to #{temp} degrees."
        else
          say "Sorry, there was a problem setting the temperature"
        end
      else
        say "Sorry, the thermostat is unreachable."
      end
        
      request_completed #always complete your request! Otherwise the phone will "spin" at the user!
    }    
  end
  
  def show_temperature(thermostat_name)
    get_thermostat_by_name(thermostat_name)
    say "Checking the temperature indicated by #{self.thermostat_name} thermostat"
    
    Thread.new {
      page = HTTParty.get("http://#{self.thermostat}/tstat").body rescue nil
      status = JSON.parse(page) rescue nil
      
      if status
        say "The current temperature indicated by #{self.thermostat_name} thermostat is #{status["temp"]} degrees."      
      else
        say "Sorry, the thermostat is unreachable."
      end
        
      request_completed #always complete your request! Otherwise the phone will "spin" at the user!
    }
  end

  def remove_hold(thermostat_name)
    get_thermostat_by_name(thermostat_name)

    page = HTTParty.get("http://#{self.thermostat}/tstat").body rescue nil
    status = JSON.parse(page) rescue nil
      
    if status
      device_type = (status["tmode"] == 1 ? "heater" : "air conditioner")
     
      status = HTTParty.post("http://#{self.thermostat}/tstat", :body => {
 				        	    :hold   => 0,
					  	    :tmode  => status["tmode"]
						}.to_json)
                     
      if status["success"] == 0
        say "The temperature hold on #{self.thermostat_name} thermostat has been removed."
      else
        say "Sorry, there was a problem removing the hold status on #{self.thermostat_name} thermostat"
      end
    else
      say "Sorry, the #{self.thermostat_name} thermostat is unreachable."
    end
  end

  def set_hold(thermostat_name)
    get_thermostat_by_name(thermostat_name)
    say "Setting temperature hold on #{self.thermostat_name} thermostat"

    Thread.new {
      page = HTTParty.get("http://#{self.thermostat}/tstat").body rescue nil
      status = JSON.parse(page) rescue nil
      
      if status
        device_type = (status["tmode"] == 1 ? "heater" : "air conditioner")

        update = HTTParty.post("http://#{self.thermostat}/tstat", :body => {
							      :hold   => 1,
                                                              :tmode  => status["tmode"],
                                                              :t_heat => status["t_heat"]
                                                            }.to_json)
                     
        if update["success"] == 0
          say "The #{device_type} has been set to hold #{status["t_heat"]} degrees."
        else
          say "Sorry, there was a problem setting the hold status"
        end
      else
        say "Sorry, the thermostat is unreachable."
      end
        
      request_completed #always complete your request! Otherwise the phone will "spin" at the user!
   }
  end

  def set_thermostats_away
    self.thermostats.each do |key,value|
      get_thermostat_by_name(key)

      page = HTTParty.get("http://#{self.thermostat}/tstat").body rescue nil
      status = JSON.parse(page) rescue nil
      
      if status
        device_type = (status["tmode"] == 1 ? "heater" : "air conditioner")
	hold_value = (status["tmode"] == 1 ? self.away_heat : self.away_cool)
      
        status = HTTParty.post("http://#{self.thermostat}/tstat", :body => {
					        	          :hold   => 1,
							  	  :tmode  => status["tmode"],
							  	  :t_heat => hold_value.to_i
								}.to_json)
                     
        if status["success"] == 0
          say "The #{self.thermostat_name} thermostat has been set to hold the #{device_type} at #{hold_value} degrees."
        else
          say "Sorry, there was a problem setting the hold status on the #{self.thermostat_name} thermostat"
        end
      else
        say "Sorry, the #{self.thermostat_name} thermostat is unreachable."
      end
    end
    request_completed #always complete your request! Otherwise the phone will "spin" at the user!
  end

  def set_thermostats_back
    self.thermostats.each do |key,value|
      get_thermostat_by_name(key)
      remove_hold(self.thermostat_name)
    end
    request_completed #always complete your request! Otherwise the phone will "spin" at the user!
  end
end
