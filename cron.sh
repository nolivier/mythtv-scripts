#!/bin/bash
LOG=/var/log/mythtv/myth-cron.log

log()
{
        echo "$(date +'%Y-%m-%d %H:%M:%S') - myth-cron - $1" >> $LOG
}

log "Lancement grab kazer"
/home/nolivier/.mythtv/scripts/grab_kazer.sh

log "Lancement sauvegarde bdd"
/usr/share/mythtv/mythconverg_backup.pl

log "Lancement JAMU en mode maintenance"
sudo -u mythtv /usr/share/mythtv/mythvideo/scripts/jamu.py -l fr -C "/home/nolivier/.mythtv/jamu.conf" -M >> $LOG

log "Lancement JAMU en mode traitement des enregistrements"
sudo -u mythtv /usr/share/mythtv/mythvideo/scripts/jamu.py -l fr -C "/home/nolivier/.mythtv/jamu.conf" -MW >> $LOG
if [ $(date +'%u') -eq 7 ]
then
  log "Debut de traitement hebdomadaire"

  log "Lancement JAMU en mode janitor"
  sudo -u mythtv /usr/share/mythtv/mythvideo/scripts/jamu.py -l fr -C "/home/nolivier/.mythtv/jamu.conf" -MJ >> $LOG
fi

log "Fin du cronjob"
