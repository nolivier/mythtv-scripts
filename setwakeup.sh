#!/bin/bash
#
# . Sets ACPI wakeup time
#
# . Input parameters $* are the date/time in any valid format
#
# . Assumes that RTC is localtime and not UTC
#
# . Works whether system sets ACPI wakeup time with either:
#	/proc/acpi/alarm
#	/sys/class/rtc/rtc0/wakealarm
#
# . Corrects schedulting conflicts between recording time and daily
#	wakeup time caused by Mythwelcome (at least in MythDora 5.0)
#
# . Appends status messages to log file: /var/log/mythtv/mythtv-script.log
#
# . Keeps record of wakeup time in file: /var/log/mythtv/wakeupspec
#	File format is "%s %s"
#		- where first item is epoch seconds of when requested
#		- where second iten is epoch seconds of wakeup time

# Current time and date
NOW=`date "+%F %T"`

# Helper prints messages to wakeup log
function logtowakeup()
	{
	echo "$(date +'%Y-%m-%d %H:%M:%S') - setwakeup - $1" >> /var/log/mythtv/mythtv-script.log
	}

# Rewrite time/date parameter into standardized format. If failure,
# then try again assuming input is in epoch seconds. A second failure
# produces error for invalid date and exits.
DATE=`date -d "$*" "+%F %H:%M:%S" -u`
if [ $? -ne 0 ]; then
	DATE=`date -d "@$*" "+%F %H:%M:%S" -u`
	if [ $? -ne 0 ]; then
	logtowakeup "$* invalid date specification"
		exit 1
	fi
fi

# Log the wakeup request
logtowakeup "wakeup requested : $*"

# Current time in seconds
NOWSECS=`date -d "$NOW" "+%s"`

# Requested wakeup time in seconds
SECS=`date -d "$DATE" "+%s" -u`

# If this wakeup setting has been issued within a second of the previous
# one, then mythwelcome is schizophrenic. Actually, this happens because
# there is both a daily wakeup and a scheduled recording. Mythwelcome
# will fire off both requests without predjudice. The earlier of the two
# wakeup times is retained.
if [ -e /var/log/mythtv/wakeupspec ]; then
	set -- `cat /var/log/mythtv/wakeupspec`
	if [ $(($NOWSECS-$1)) -lt 2 ] && [ $SECS -gt $2 ]; then
		LASTDATE=`date -d "@$2" "+%F %H:%M:%S" -u`
		logtowakeup "keeping previous wakeup $LASTDATE"
		exit 0
	fi
fi

# Save wakeup specification
echo "$NOWSECS $SECS" > /var/log/mythtv/wakeupspec

# There are two methods for setting the ACPI wakeup time. Newer Linux
# kernels write epoch time to /sys/class/rtc/rtc0/wakealarm. wakealarm
# must be set zero prior to setting the desired value.
if [ -e /sys/class/rtc/rtc0/wakealarm ]; then
	echo 0 > /sys/class/rtc/rtc0/wakealarm
	echo $SECS > /sys/class/rtc/rtc0/wakealarm
	logtowakeup "writing $DATE to /sys/class/rtc/rtc0/wakealarm"
fi

# Supposedly the /proc/acpi/alarm method is deprecated, however this
# is supported by MythDora 5.0
if [ -e /proc/acpi/alarm ]; then
	echo $DATE > /proc/acpi/alarm
	logtowakeup "writing $DATE to /proc/acpi/alarm"
fi

