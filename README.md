Carelink Notificator
====================

Ruby script that uses decoding-carelink ( http://github.com/bewest/decoding-carelink/ ) to download Glucose History from a Medtronic pump and sends BG notifications to services such as Pushover

This script is still under testing.

As of now, it notifies for:

— High Blood Glucose

— Low Blood Glucose

— Out of Range error ( For when the Carelink cannot access the Pump data )

— NEW Upward BG trends ( customizable )

— NEW Downward BG trends ( customizable )

![Alt text](IMG_0345.PNG?raw=true "Pushover App on iOS")

How is it used?
====================

This script was developed to be used on a Raspberry Pi with the Carelink USB. Its objective is to have hardware that can download CGM history data from a Medtronic pump and can notify services such as Pushover ( http://pushover.net )

You basically power-up the Raspberry Pi and automatically it will start running the script every X amount of time ( using cronjob ) and it will notify Pushover everytime.

![Alt text](IMG_0325.JPG?raw=true "Rasbperry Pi Setup")

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

— Install Python on the Raspberry, clone the decoding-carelink repository on your Pi. Before proceeding, make sure you are able to read from the Carelink USB. ( follow instructions on http://github.com/bewest/decoding-carelink/ )

— Internet connection. You can set up an internet connection through Ethernet cable ( easy way ) or using a WiFi USB dongle ( guides for setting this up can be found online ).

— Clone the carelink_notificator repository on your Pi: 

```
git clone https://github.com/bustavo/carelink_notificator.git
```

— Install ruby 

```
sudo apt-get install ruby1.9.1-dev
````

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

— Just Power-up when wanting to use it and maintain a close range between the Carelink USB and the pump.

— Power-down when going away or when stopping using it.

EXTRAS
====================

— Make the Raspberry Pi power off when removing the Carelink USB

First run

```
udevadm monitor --udev --property
```

Then, unplug the Carelink USB. You will see a set of properties displayed on the screen. Take note of ID_VENDOR_ID & ID_MODEL_ID

After that, create a new file in /etc/udev/rules.d/ ( You can name it however you want )

Add to the file:

```
ACTION=="remove", ENV{ID_VENDOR_ID}=="YOUR_VENDOR_ID", ENV{ID_MODEL_ID}=="YOUR_MODEL_ID", RUN+="/sbin/shutdown -h now"
```

Now save, exit and reload the rules:

```
udevadm control --reload-rules
```

That's it! Next time you unplug the Carelink USB, the Raspberry Pi will shutdown, just remember to wait a couple of seconds before disconnecting ( The PWR led stays on ).

— I added a piezo-buzzer to the Raspberry Pi so that it can alert me with sound if there is no internet connection in case it is needed. If you are interested on knowing how I did this, contact me, I will be happy to help :)