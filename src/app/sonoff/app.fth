\ Load file for using MQTT to control a Sonoff Switch
\ There are many references on the net showing how to
\ open up a Sonoff device and replace its firmware.
\ This code has been tested on a Sonoff S20 but it
\ should work with numerous Sonoff switchs since they
\ all seem to use the same GPIOs.

\ You will need to run an MQTT server on some other
\ machine.  The client ID is "Sonoff Switch Forth"
\ Read the pushbutton by subscribing to sonoff/switch
\ You can control the device by publishing to
\   sonoff/relay   (AC relay and associated red LED)
\   sonoff/led     (green LED)
\ For all the above topics, the values are On and Off

fl ../esp8266/common.fth
fl ../../lib/random.fth

also modem
: rx  ( -- )  pad  unused pad here - -  (receive)  #100 ms  ;
previous

\ The default value of switch-gpio (3) is correct
fl ../esp8266/gpio-switch.fth

6 constant relay-gpio  \ Active high, also red LED
7 constant green-led-gpio  \ Active-low
5 constant sensor-gpio

: green-led-off  ( -- )  1 green-led-gpio gpio-pin!  ;
: green-led-on  ( -- )  0 green-led-gpio gpio-pin!  ;
: relay-off  ( -- )  0 relay-gpio gpio-pin!  ;
: relay-on  ( -- )  1 relay-gpio gpio-pin!  ;
: init-gpios  ( -- )
   0 gpio-input switch-gpio gpio-mode
   0 gpio-output relay-gpio gpio-mode
   0 gpio-output green-led-gpio gpio-mode
   0 gpio-input sensor-gpio gpio-mode
   relay-off
   green-led-off
;

fl ../esp8266/wifi.fth
fl ../esp8266/tcpnew.fth

fl ../esp8266/resolve.fth

\ The server name or IP address is read at startup
\ time from the wifi-on file
: mqtt-server$  ( -- $ )  " server$" evaluate  ;
: mqtt-client-id$  ( -- $ )  " Sonoff Switch Forth"  ;
: mqtt-username$  ( -- $ )  " "  ;
: mqtt-password$  ( -- $ )  " "  ;
: mqtt-will$  ( -- msg$ topic$ )  " "  " "  ;
0 value mqtt-will-qos     \ 0, 1, 2, 3
0 value mqtt-will-retain  \ 0 or 1
0 value mqtt-clean-session
0 value mqtt-keepalive    \ seconds

fl mqtt.fth

also mqtt-topics definitions
: sonoff/relay  ( value$ -- )
   2dup  " On"  $=  if  2drop relay-on exit  then
   " Off" $=  if  relay-off  then
;
: sonoff/led  ( value$ -- )
   2dup  " On"  $=  if  2drop green-led-on exit  then
   " Off" $=  if  green-led-off  then
;
previous definitions

: subscribe-relay  ( -- )
   0 " sonoff/led"  0 " sonoff/relay"  2  #1234 mqtt-subscribe
;
0 value last-switch
: switch-changed?  ( -- flag )  switch? last-switch <>  ;
: publish-switch  ( -- )
   switch? dup  if  " On"  else  " Off"  then  " sonoff/switch" 0 0 mqtt-publish-qos0
   to last-switch
;
: run  ( -- )
   init-gpios
   green-led-on
   green-led-off

   " wifi-on" included

   mqtt-start
   green-led-on
   subscribe-relay
   publish-switch
   #200 ms green-led-off
   begin
      #100 ms
      switch-changed?  if  publish-switch  then
   key? until
;

: app
   banner decimal
   interrupt?  if  quit  then
   ['] load-startup-file catch drop
   decimal
   run
   quit
;

" app.dic" save
