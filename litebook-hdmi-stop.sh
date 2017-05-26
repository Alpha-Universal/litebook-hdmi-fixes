#!/bin/bash -

#   Name    :   litebook-hdmi-stop.sh
#   Author  :   Richard Buchanan II for Alpha Universal, LLC
#   Brief   :   A script that stops all HDMI output for the Litebook v1. 
#

set -o errexit      # exits if non-true exit status is returned
set -o nounset      # exits if unset vars are present

# fail _if_ running as root
if [[ $EUID == 0 ]] ; then
	echo "This script should not be run with root privileges." ;
	echo "Please re-run this script without sudo." ;
	exit 1 ;
fi

PATH=/usr/local/bin:/usr/bin:/bin:/sbin:/usr/sbin:/usr/local/sbin

mons_avail="$(find /home/"$(whoami)"/bin/litebook/ -type f -name "*hdmi-start.sh" | sed s/-hdmi-start.sh//)"

# needed to call the current display
DISPLAY=:0
export DISPLAY
XAUTHORITY=/home/"$(whoami)"/.Xauthority
export XAUTHORITY

# disable HDMI output
xrandr --output HDMI1 --off

exit 0
