#-*- encoding: utf-8 -*-
require 'rubygems'
require 'json'
require 'rushover'

# SETUP START ( Customize according to your configuration )

raspberry_time = Time.now - 21600 # Time.now +/- OFFSET_IN_SECONDS
decoding_carelink_path = "/home/pi/decoding-carelink"

pumpl_serial = "123456"
lo_bg_limit = 75
hi_gb_limit = 160

pushover_app_key = "YOUR_APP_KEY" # Set one up on your Pushover account
pushover_client_key = "YOUR_CLIENT_KEY" # Get it on your Pushover account

# SETUP END

# NOTIFICATION CODE START

# Pushover client setup
pushover_client = Rushover::Client.new(pushover_app_key)

# Get Page Number using decoding-carelink
page_request = `python #{decoding_carelink_path}/bin/mm-send-comm.py --init --serial #{pumpl_serial} --port /dev/ttyUSB0 --prefix-path #{decoding_carelink_path}/bin/step1  --prefix ReadCurGlucosePageNumber --save sleep 0`

if page_request && page_request.partition("page': ").last.split(",")[0]

  page = page_request.partition("page': ").last.split(",")[0].split("L")[0]

  # Download Glucose History
  `python #{decoding_carelink_path}/bin/mm-send-comm.py --serial #{pumpl_serial} --port /dev/ttyUSB0 --prefix-path #{decoding_carelink_path}/bin/ tweak ReadGlucoseHistory --page #{page} --save`

  # Decode Glucose History
  history = `python #{decoding_carelink_path}/list_cgm.py #{decoding_carelink_path}/bin/ReadGlucoseHistory-page-#{page}.data`

  if history

    # Init Latest Values
    last_bg = 0
    last_date = ""

    # Get Latest Values
    JSON.parse(history).each do |history|
      if history.size
        history.each do |hist|
          if hist.kind_of?(Array)
          elsif hist["name"] == "GlucoseSensorData"
            last_date = hist["date"]
            last_bg = hist["sgv"]
          end
        end
      end
    end
            
    # If date is older than 20 minutes, we probably have not calibrated! Let me know I need calibration. We adjust Raspberry Time to match local time.
    last_date_ruby = Time.new(last_date.split("T")[0].split("-")[0].to_i,last_date.split("T")[0].split("-")[1].to_i,last_date.split("T")[0].split("-")[2].to_i,last_date.split("T")[1].split(":")[0].to_i,last_date.split("T")[1].split(":")[1].to_i,last_date.split("T")[1].split(":")[2].to_i)
    
    if (last_date_ruby+(20*60)) < raspberry_time
      
      # Send as important message
      resp = pushover_client.notify(pushover_client_key, "The latest data found is more than 20 minutes old! Needs calibration?", :priority => 1, :title => "OLD DATA ALERT!")
            
    else
        
      if last_bg.to_i < lo_bg_limit
        # Send as important message
        resp = pushover_client.notify(pushover_client_key, "#{last_bg} Blood Glucose @ #{last_date}", :priority => 1, :title => "LOW BLOOD GLUCOSE!")
      elsif last_bg.to_i > hi_gb_limit
        # Send as important message
        resp = pushover_client.notify(pushover_client_key, "#{last_bg} Blood Glucose @ #{last_date}", :priority => 1, :title => "HIGH BLOOD GLUCOSE!")
      else
        # Send as normal message
        resp = pushover_client.notify(pushover_client_key, "#{last_bg} Blood Glucose @ #{last_date}", :title => "#{last_bg} Blood Glucose")
      end
    
    end
    
  else

    #Notify disconnection to pushover
    resp = pushover_client.notify(pushover_client_key, "Data not accessible! Are we out of range?", :priority => 1, :title => "DATA NOT ACCESSIBLE!")

  end

else

  #Notify disconnection to pushover
  resp = pushover_client.notify(pushover_client_key, "Data not accessible! Are we out of range?", :priority => 1, :title => "DATA NOT ACCESSIBLE!")

end

# NOTIFICATION CODE END
