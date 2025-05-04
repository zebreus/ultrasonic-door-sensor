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
// Topics for subscribed values
sleep-duration-topic := (base_topic) + "sleep-duration"
sleep-duration-duration-topic := (base_topic) + "sleep-duration-duration"

// Initialize complex global variables
config_bucket := storage.Bucket.open --flash "config_bucket"
mqtt_client := mqtt.Client --host=HOST
trigger := gpio.Pin TRIGGER
echo := gpio.Pin ECHO
sensor := hc-sr04.Driver --echo=echo --trigger=trigger

door-open := false
DEFAULT_SLEEP_DURATION := Duration --s=2
// The duration for which a custom sleep duration is active
DEFAULT_SLEEP_DURATION_DURATION := Duration --s=120
sleep_duration := DEFAULT-SLEEP-DURATION
reset-sleep-duration-at := Time.now + DEFAULT_SLEEP_DURATION_DURATION

DEEP_SLEEP_THRESHOLD := Duration --s=3
NORMAL_SLEEP_AFTER_DEEP_SLEEP := Duration --ms=500

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
  
sleep-or-deep-sleep:
  if sleep-duration < DEEP_SLEEP_THRESHOLD:
    sleep sleep-duration
  else:
    print "Deep-sleeping sleeping for $sleep_duration"
    esp32.deep-sleep (sleep-duration - NORMAL_SLEEP_AFTER_DEEP_SLEEP)
    // Short read + extra sleep to help the sensor wake up
    sensor.read-distance
    sleep NORMAL_SLEEP_AFTER_DEEP_SLEEP

  
  if Time.now > reset-sleep-duration-at and sleep-duration != DEFAULT_SLEEP_DURATION:
    sleep-duration = DEFAULT_SLEEP_DURATION
    print "Sleep duration reset to default: $sleep_duration"
    reset-sleep-duration-at = Time.now + DEFAULT_SLEEP_DURATION_DURATION

main:
  mqtt_client.start
    --client-id=CLIENT-ID
    --on-error=:: print "MQTT error: $it"
    --reconnection-strategy=mqtt.TenaciousReconnectionStrategy --delay-lambda=:: Duration --s=(it < 30 ? 2 : 15)
  print "MQTT client connected"

  mqtt_client.subscribe sleep-duration-topic:: | topic/string payload/ByteArray |
    catch --trace:
      decoded := json.decode payload
      print "Received value on '$topic': $decoded"
      if decoded is int:
        // Limit to a maximum sleep duration of 60 seconds
        if decoded > 60: decoded = 60
        if decoded < 0: decoded = 0

        sleep_duration = Duration --s=decoded
        reset-sleep-duration-at = Time.now + DEFAULT_SLEEP_DURATION_DURATION
        print "Sleep duration set to $sleep_duration"
      else:
        print "Invalid value received on '$topic': $decoded"
  
  mqtt_client.subscribe sleep-duration-duration-topic:: | topic/string payload/ByteArray |
    catch --trace:
      decoded := json.decode payload
      print "Received value on '$topic': $decoded"
      if decoded is int:
        // Limit to a maximum sleep duration of 60 seconds
        MAX_SLEEP_DURATION_DURATION := 60*60*24*365
        if decoded > MAX_SLEEP_DURATION_DURATION: decoded = MAX_SLEEP_DURATION_DURATION
        if decoded < 0: decoded = 0
        if decoded == 0: decoded = MAX_SLEEP_DURATION_DURATION

        reset-sleep-duration-at = Time.now + (Duration --s=decoded)
        print "Keeping the current sleep-duration until $reset-sleep-duration-at"
      else:
        print "Invalid value received on '$topic': $decoded"

  while true:
    catch --trace:
      measure
      sleep-or-deep-sleep

  