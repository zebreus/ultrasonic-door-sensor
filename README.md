# ultrasonic-door-sensor

This project is a firmware for an ESP32-based MQTT-enabled door sensor, which uses an HC-SR04 ultrasonic distance sensor to detect whether a door/window/ or similar is open or closed.

## Features

- Publishes and open/closed status (and measured distance) via **MQTT**
- Supports **deep sleep** for power efficiency
- Allows dynamic configuration of sleep duration via MQTT
- Supports OTA updates with jaguar/toit

## Configuration

Adjust the following constants in the source code as needed:

| Constant                     | Description                                            |
| ---------------------------- | ------------------------------------------------------ |
| `HOST`                       | MQTT broker IP address                                 |
| `PREFIX`, `LOCATION`, `NAME` | Used to construct the MQTT topic hierarchy             |
| `TRIGGER`, `ECHO`            | GPIO pin numbers for the sensor's trigger and echo     |
| `DOOR_OPEN_THRESHOLD_MM`     | Distance (in mm) above which door is considered open   |
| `DOOR_CLOSED_THRESHOLD_MM`   | Distance (in mm) below which door is considered closed |
| `DEFAULT_SLEEP_DURATION`     | How often to measure in normal operation               |

## Installation

Follow the [toit installation instructions](https://docs.toit.io/getstarted/device) to follow the steps to install the toit/jaguar firmware on your ESP32. Afterwards you can use the following command to install this project:

```bash
jag container install ultrasonic-door-sensor main.toit
```

Optional: Look at the logs to confirm its running. You should see distance measurement results.

```bash
jag monitor attach
```

## MQTT Topics

### Published Topics

- `{PREFIX}/{LOCATION}/{NAME}/raw`
  Publishes the raw distance value in millimeters.

- `{PREFIX}/{LOCATION}/{NAME}/open`
  Publishes `"1"` if the door is open, `"0"` if closed.

### Subscribed Topics

- `{PREFIX}/{LOCATION}/{NAME}/sleep-duration`
  Accepts an integer (0–60) to override the sleep duration in seconds.

- `{PREFIX}/{LOCATION}/{NAME}/sleep-duration-duration`
  Accepts an integer to define how long the currently active custom sleep duration remains active (in seconds). A value of `0` is treated as permanent. A reboot always resets the custom sleep duration to `DEFAULT_SLEEP_DURATION`.

## Power Management

- If `sleep_duration < 3s`, the ESP32 enters **light sleep**.
- If `sleep_duration >= 3s`, the ESP32 enters **deep sleep**, which reduces power consumption significantly to about 2mA. 90% of the remaining power consumption is caused by the HC-SR04 sensor.
