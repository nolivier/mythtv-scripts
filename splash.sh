#!/bin/bash

PID_F=/home/nolivier/.mythtv/splash.pid
#slides="logo_xtra_large.png logo_large.png logo_medium.png logo_small.png logo_medium.png logo_large.png"
slides="/usr/share/images/xsplash/logo_xtra_large.png"
case "$1" in
  start)
	feh -F --hide-pointer --slideshow-delay 1 $slides &
	echo $! > $PID_F
	;;
  stop)
        kill `cat $PID_F`
        ;;
esac

