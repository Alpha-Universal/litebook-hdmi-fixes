#!/bin/bash -

#   Name    :   litebook-hdmi-template.sh
#   Author  :   Richard Buchanan II for Alpha Universal, LLC
#   Brief   :   A template that will capture all configurations from
#				litebook-hdmi* scripts and be installed in a user's home dir
#				for easy execution
#

set -o errexit      # exits if non-true exit status is returned
set -o nounset      # exits if unset vars are present

PATH=/usr/local/bin:/usr/bin:/bin:/sbin:/usr/sbin:/usr/local/sbin

# fail _if_ running as root
if [[ $EUID == 0 ]] ; then
	echo "This script should not be run with root privileges." ;
	echo "Please re-run this script without sudo." ;
	exit 1 ;
fi

# needed to call the current display
DISPLAY=:0
export DISPLAY
XAUTHORITY=/home/"$(whoami)"/.Xauthority
export XAUTHORITY

# needed to set the monitor's mode as part of monitor setup
# this command only requires a single run, and will be 
# commented out after
xrandr --newmode "1920x1080_60.00" 

# needed to activate HDMI output after each reboot
#xrandr --addmode HDMI1 1920x1080
#xrandr --output HDMI1 --mode 1920x1080 --TRANS --POS

exit 0
