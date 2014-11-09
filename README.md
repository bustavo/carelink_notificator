Carelink Notificator
====================

Ruby script that uses decoding-carelink ( http://github.com/bewest/decoding-carelink/ ) to download Glucose History from a Medtronic pump and sends notifications to services such as Pushover

How is it used?
====================

This script was developed to be used on a Raspberry Pi with the Carelink USB. Its objective is to have hardware that can download CGM history data from a Medtronic pump and can notify services such as Pushover ( http://pushover.net )

You basically power-up the Raspberry Pi and automatically it will start running the script every X amount of time ( using cronjob ) and it will notify Pushover everytime.

What you need?
====================

Hardware:
Raspberry Pi with its power adapter
Carelink USB
Wifi usb dongle ( Optional, as you can connect the device through Ethernet )

Software:
Python installed on the Raspberry Pi ( There are a lot of guides on how to set this up, just Google it )
decoding-carelink ( http://github.com/bewest/decoding-carelink/ )
Account on Pushover.net

Set-up
====================

— Set up an account on Pushover.net If you are using the mobile app, you can set up the account from there.

— Install Python on the Raspberry, clone the decoding-carelink repository on your Pi. Before proceeding, make sure you are able to read from the Carelink USB.

— Internet connection. You can set up an internet connection through Ethernet cable ( easy way ) or using a WiFi USB dongle ( guides for setting this up can be found online ).

— Clone the carelink_notificator repository on your Pi: git clone https://github.com/bustavo/carelink_notificator.git

— Install required gems with the following commands: 

```
sudo gem install json
sudo gem install rushover
```

— Open up ruby-carelink.rb using the editor of your choice:

```
sudo nano ruby-carelink.rb
```

— Edit the following variables:

```
raspberry_time = Time.now - 21600 # My Raspberry time was off by a couple of hours so I had to manually adjust the time by substracting seconds
decoding_carelink_path = "/home/pi/decoding-carelink" # Define the path where decoding-carelink was cloned
pumpl_serial = "123456" # Your Medtronic serial number ( only the numbers )
lo_bg_limit = 75 # Set your low BG level for alerts
hi_gb_limit = 160 # Set your high BG level for alerts
pushover_app_key = "YOUR_APP_KEY" # You can get one on your Pushover account
pushover_client_key = "YOUR_CLIENT_KEY" # You can get this on your Pushover account
```

— Do a test run:

```
ruby ruby-carelink.rb
```

— If everything goes OK you will receive a notification on your Pushover app.

— Configure cronjobs so the script can run automatically once the Raspberry Pi is powered on. On your Raspberry Pi run:

```
crontab -e
```

— Add the following lines to the file:

```
*/10 * * * * ruby /path_to_carelink_notificator/ruby-carelink.rb
@reboot ruby /path_to_carelink_notificator/ruby-carelink-setup.rb
```

The first line tells the Raspberry to run the script every 10 minutes.

The second line tells the Raspberry to configure the Carelink USB ( from the decoding-carelink instructions ) everytime it boots.
