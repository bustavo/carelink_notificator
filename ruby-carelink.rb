#-*- encoding: utf-8 -*-
require 'rubygems'
require 'json'
require 'rushover'

# SETUP START ( Customize according to your configuration )

raspberry_time = Time.now - 21600                     # Time.now +/- OFFSET_IN_SECONDS // If your Raspberry Pi time is correct, just leave Time.now
decoding_carelink_path = "/home/pi/decoding-carelink" # Path to Ben West's decoding-carelink repository on your Raspberry Pi

pumpl_serial = "123456"                               # Your pump's serial number
lo_bg_limit = 75                                      # Below or equal to this BG level, the message will be sent with important priority
hi_gb_limit = 280                                     # Above or equal to this BG level, the message will be sent iwth important priority

upward_trend_count = 4                                # How many consecutive upward measurements to consider before sending an alarm
downward_trend_count = 4                              # How many consecutive downward measurements to consider before sending an alarm
trend_units_difference = 15                           # How much difference ( in blood glucose ) should there be from the initial step measurement to the last step measurement before sending an alarm

pushover_app_key = "YOUR_APP_KEY"                     # Set one up on your Pushover account
pushover_client_key = "YOUR_CLIENT_KEY"               # Get it on your Pushover account

# SETUP END

# NOTIFICATION CODE START

# Check for internet connection. Restart if there is none. Give 5 minutes of wait time.
unless `ifconfig wlan0 | grep -q "inet addr:"`
  
  # Sleep 4 minutes & reactivate internet connection
  sleep(4.minutes)
  `ifup --force wlan0`
  sleep(1.minutes)
  
end

if `ifconfig wlan0 | grep -q "inet addr:"`

  # Pushover client setup
  pushover_client = Rushover::Client.new(pushover_app_key)

  # Get Page Number using decoding-carelink
  page_request = `python #{decoding_carelink_path}/bin/mm-send-comm.py --init --serial #{pumpl_serial} --port /dev/ttyUSB0 --prefix-path #{decoding_carelink_path}/bin/step1  --prefix ReadCurGlucosePageNumber --save sleep 0`

  if page_request && page_request.partition("page': ").last.split(",")[0]

    page = page_request.partition("page': ").last.split(",")[0].split("L")[0].to_i

    # Download Glucose History
    `python #{decoding_carelink_path}/bin/mm-send-comm.py --serial #{pumpl_serial} --port /dev/ttyUSB0 --prefix-path #{decoding_carelink_path}/bin/ tweak ReadGlucoseHistory --page #{page} --save`

    # Decode Glucose History
    history = `python #{decoding_carelink_path}/list_cgm.py #{decoding_carelink_path}/bin/ReadGlucoseHistory-page-#{page}.data`

    if history

      # Init Latest Values
      last_bg = 0
      last_date = Time.now
      found_glucose_sensor_data = 0

      # Check for upward or downward trend
      bg_array = []

      # Get Latest Values
      JSON.parse(history).each do |history|
        if history.size
          history.each do |hist|
            if hist.kind_of?(Array)
            elsif hist["name"] == "GlucoseSensorData"
              found_glucose_sensor_data = 1
              bg_array.push(hist["sgv"].to_i)
              last_date = hist["date"]
              last_bg = hist["sgv"]
            end
          end
        end
      end
      
      # Check for upward or downward trend
      up_count = 0
      down_count = 0
      back_count = 4
      
      if upward_trend_count > downward_trend_count
        back_count = upward_trend_count
      else
        back_count = downward_trend_count
      end
      
      if bg_array.size.to_i > (back_count + 1)
                  
        (bg_array.size.to_i - back_count).upto(bg_array.size.to_i) do |n|
          if bg_array[n] && (bg_array[n] > bg_array[n-1])
            up_count = up_count + 1
            trend_units_difference = trend_units_difference - (bg_array[n] - bg_array[n-1])
          end
          if bg_array[n] && (bg_array[n] < bg_array[n-1])
            down_count = down_count + 1
            trend_units_difference = trend_units_difference - (bg_array[n-1] - bg_array[n])
          end
        end
      
      end
      
      # If there is no GlucoseSensorData found, we probably just flipped to a new page, so we should try with the page before?
      if found_glucose_sensor_data == 0
    
        # Download Glucose History
        `python #{decoding_carelink_path}/bin/mm-send-comm.py --serial #{pumpl_serial} --port /dev/ttyUSB0 --prefix-path #{decoding_carelink_path}/bin/ tweak ReadGlucoseHistory --page #{page - 1} --save`

        # Decode Glucose History
        history = `python #{decoding_carelink_path}/list_cgm.py #{decoding_carelink_path}/bin/ReadGlucoseHistory-page-#{page - 1}.data`
    
        # Init Latest Values
        last_bg = 0
        last_date = Time.now

        # Check for upward or downward trend
        bg_array = []

        # Get Latest Values
        JSON.parse(history).each do |history|
          if history.size
            history.each do |hist|
              if hist.kind_of?(Array)
              elsif hist["name"] == "GlucoseSensorData"
                bg_array.push(hist["sgv"].to_i)
                last_date = hist["date"]
                last_bg = hist["sgv"]
              end
            end
          end
        end
        
        # Check for upward or downward trend
        up_count = 0
        down_count = 0
        back_count = 4
      
        if upward_trend_count > downward_trend_count
          back_count = upward_trend_count
        else
          back_count = downward_trend_count
        end
      
        if bg_array.size.to_i > (back_count + 1)
                  
          (bg_array.size.to_i - back_count).upto(bg_array.size.to_i) do |n|
            if bg_array[n] && (bg_array[n] > bg_array[n-1])
              up_count = up_count + 1
              trend_units_difference = trend_units_difference - (bg_array[n] - bg_array[n-1])
            end
            if bg_array[n] && (bg_array[n] < bg_array[n-1])
              down_count = down_count + 1
              trend_units_difference = trend_units_difference - (bg_array[n-1] - bg_array[n])
            end
          end
      
        end
        
      end
          
      # If date is older than 20 minutes, we probably have not calibrated! Let me know I need calibration. We adjust Raspberry Time to match local time.
      last_date_ruby = Time.new(last_date.split("T")[0].split("-")[0].to_i,last_date.split("T")[0].split("-")[1].to_i,last_date.split("T")[0].split("-")[2].to_i,last_date.split("T")[1].split(":")[0].to_i,last_date.split("T")[1].split(":")[1].to_i,last_date.split("T")[1].split(":")[2].to_i)
  
      if (last_date_ruby+(20*60)) < raspberry_time
      
        if found_glucose_sensor_data == 0

          # Let me know, I still don't have new data to send :(
          resp = pushover_client.notify(pushover_client_key, "We should wait a couple of hours for new data :(", :title => "DATA NOT ACCESSIBLE")
              
        else

          # Send as important message
          resp = pushover_client.notify(pushover_client_key, "The latest data found is more than 20 minutes old! Needs calibration?", :priority => 1, :title => "OLD DATA ALERT!")
    
        end
    
      else
      
        if last_bg.to_i < lo_bg_limit

          # Send as important message
          resp = pushover_client.notify(pushover_client_key, "#{last_bg} BG @ #{last_date_ruby.hour}:#{last_date_ruby.min} - #{last_date_ruby.day}/#{last_date_ruby.month}", :priority => 1, :title => "LOW BLOOD GLUCOSE!")

        elsif last_bg.to_i > hi_gb_limit

          # Send as important message
          resp = pushover_client.notify(pushover_client_key, "#{last_bg} BG @ #{last_date_ruby.hour}:#{last_date_ruby.min} - #{last_date_ruby.day}/#{last_date_ruby.month}", :priority => 1, :title => "HIGH BLOOD GLUCOSE!")
          
        elsif (up_count >= upward_trend_count) && ( trend_units_difference <= 0 )

          # Up Emoji    \xF0\x9F\x94\xBC 

          # Send as important message
          resp = pushover_client.notify(pushover_client_key, "#{last_date_ruby.hour}:#{last_date_ruby.min} - #{last_date_ruby.day}/#{last_date_ruby.month}", :priority => 1, :title => "\xF0\x9F\x94\xBC #{last_bg} BG")
        
        elsif down_count >= downward_trend_count && ( trend_units_difference <= 0 )
          
          # Down Emoji  \xF0\x9F\x94\xBD

          # Send as important message
          resp = pushover_client.notify(pushover_client_key, "#{last_date_ruby.hour}:#{last_date_ruby.min} - #{last_date_ruby.day}/#{last_date_ruby.month}", :priority => 1, :title => "\xF0\x9F\x94\xBD #{last_bg} BG")
            
        else
                      
          # Send as normal message
          resp = pushover_client.notify(pushover_client_key, "#{last_date_ruby.hour}:#{last_date_ruby.min} - #{last_date_ruby.day}/#{last_date_ruby.month}", :title => "#{last_bg} BG")

        end
  
      end
  
    else

      #Notify disconnection to pushover
      resp = pushover_client.notify(pushover_client_key, "Are we out of range?", :priority => 1, :title => "DATA NOT ACCESSIBLE!")

    end

  else

    #Notify disconnection to pushover
    resp = pushover_client.notify(pushover_client_key, "Are we out of range?", :priority => 1, :title => "DATA NOT ACCESSIBLE!")

  end

else

  # If after network reconnect there is still no internet connection, reboot system.
  `sudo shutdown -r now`

end

# NOTIFICATION CODE END
