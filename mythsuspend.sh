#!/bin/bash
log()
{
        echo "$(date +'%Y-%m-%d %H:%M:%S') - mythsuspend - $1" >> /var/log/mythtv/mythtv-script.log
}

log "Arret de mythfrontend..."
killall -q mythfrontend.real
killall -q mythlcdserver

mythshutdown -c
if [ $? -eq 0 ]
then
  /home/nolivier/.mythtv/scripts/splash.sh start &
  log "Arret de irexec..."
  killall irexec

  log "Ask for a proper shutdown"
  mythshutdown -x
else
  mythshutdown -s
  result=$?
  motif=$( mythshutdown --help | awk '/0 - Idle/,/255/ { print $0 }' | sed 's/^ *//' | grep "$result"" -" )
  log "Echec de l'arret - motif $motif"
  log "Redemarage de irexec..."
  irexec /home/nolivier/.lircrc &
  /home/nolivier/.mythtv/scripts/splash.sh stop
fi
