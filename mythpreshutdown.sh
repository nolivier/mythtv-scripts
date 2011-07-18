#!/bin/bash
log()
{
        echo "$(date +'%Y-%m-%d %H:%M:%S') - mythpreshutdown - $1" >> /var/log/mythtv/mythtv-script.log
}

log "Verification pre-arret"

BLOQ=0
BLOQUANT="plowdown"
for proc in $BLOQUANT
do
  ( ps -fC $proc | grep -q $proc ) && BLOQ=1
  log "Verification $proc - $BLOQ"
done

mythshutdown -c 
if [[ $? -eq 1 ]]
then
  BLOQ=1
fi
log "mythshutdown - $(mythshutdown -s ; echo $?)"

log "Resultat $BLOQ"
exit $BLOQ
