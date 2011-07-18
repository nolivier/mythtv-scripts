#!/bin/bash
log()
{
	echo "$(date +'%Y-%m-%d %H:%M:%S') - grab_kazer - $1" >> /var/log/mythtv/mythtv-script.log
}

log "Lancement du grabber"
cd /home/nolivier/.mythtv/xmltv
rm -f tvguide.xml    
log "Debut du telechargement"
wget -q "http://www.kazer.org/tvguide.zip?u=vkbysjgmb5pz" -O tvguide.zip

if [ $? -eq 0 ]; then
        log "Telechargement acheve"
	unzip tvguide.zip
	rm tvguide.zip
	log "Lancement de mythfilldatabase"
	mythfilldatabase --file 1 /home/nolivier/.mythtv/xmltv/tvguide.xml >> /var/log/mythtv/mythtv-script.log
else
	log "Erreur lors du telechargement"
fi
log "Fin du traitement"
