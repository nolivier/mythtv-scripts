#!/bin/bash

heure=$(date +'%H')
if [ $heure -ge 18 ] && [ $heure -le 21 ]
then
  # This script uses dbus to tell HAL to hibernate your computer
  dbus-send --system --print-reply --dest=org.freedesktop.Hal /org/freedesktop/Hal/devices/computer org.freedesktop.Hal.Device.SystemPowerManagement.Suspend int32:0
else
  shutdown -h now
fi
