import gpio
import hc-sr04
import esp32
import mqtt
import encoding.json
import device
import system.storage

// *** Configuration ***

// The MQTT broker address
HOST ::= "192.168.110.253"

// Prefix, location and name are used to construct the mqtt base topic like "$PREFIX/$LOCATION/$NAME/"
PREFIX ::= "w17"
LOCATION ::= "workshop"
NAME ::= "balconydoor"

// Pin definitions
// Trigger pin for the HC-SR04 sensor
TRIGGER ::= 5
// Echo pin for the HC-SR04 sensor
ECHO ::= 6

// The value from which the door is considered open
DOOR_OPEN_THRESHOLD_MM ::= 200
// The value from which the door is considered closed\
DOOR_CLOSED_THRESHOLD_MM ::= 50

// *** No configuration, just normal globals ***

// Initialize non-configurable global variables
CLIENT-ID ::= device.name
base_topic := "$PREFIX/$LOCATION/$NAME/"

// Topics for published values
raw_value_topic := (base_topic) + "raw"
open_topic := (base_topic) + "open"

// Initialize complex global variables
config_bucket := storage.Bucket.open --flash "config_bucket"
mqtt_client := mqtt.Client --host=HOST
trigger := gpio.Pin TRIGGER
echo := gpio.Pin ECHO
sensor := hc-sr04.Driver --echo=echo --trigger=trigger

door-open := false

// Measure the distance and publish it to the MQTT broker
measure:
  sum_of_distances := sensor.read-distance
  sleep --ms=10
  sum-of-distances += sensor.read-distance
  distance := sum_of_distances / 2

  print "measured $distance mm"
  if door-open and distance < DOOR_CLOSED_THRESHOLD_MM:
    door-open = false
  
  if (not door-open) and distance > DOOR_OPEN_THRESHOLD_MM:
    door-open = true
    
  mqtt_client.publish --qos=0 raw_value_topic "$distance"
  sleep --ms=10
  mqtt_client.publish --qos=0 open-topic "$(door-open ? "1" : "0")"
  sleep --ms=10
  
main:
  mqtt_client.start
    --client-id=CLIENT-ID
    --on-error=:: print "MQTT error: $it"
    --reconnection-strategy=mqtt.TenaciousReconnectionStrategy --delay-lambda=:: Duration --s=(it < 30 ? 2 : 15)
  print "MQTT client connected"

  
  while true:
    catch --trace:
      measure
      sleep --ms=2000
  