#!/bin/bash

log()
{
        echo "$(date +'%Y-%m-%d %H:%M:%S') - mythstart - $1" >> /var/log/mythtv/mythtv-script.log
}

log "Debut attente backend"
until wget -q http://localhost:6544 -O /dev/null
do
    sleep 1
done
# log "Demande d'arret du splah"
# (sleep 1 ; sudo dbus-send --system --type=method_call --dest=com.ubuntu.BootCurtain /com/ubuntu/BootCurtain com.ubuntu.BootCurtain.SignalLoaded string:mythfrontend) &

log "Lancement mythwelcome"
xset -dpms s off
mythfrontend --service
