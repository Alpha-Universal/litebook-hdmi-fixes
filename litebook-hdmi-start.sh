#!/bin/bash -

#   Name    :   litebook-hdmi-start.sh
#   Author  :   Richard Buchanan II for Alpha Universal, LLC
#   Brief   :   A script that enables Intel HD 400 HDMI output
#				for the Litebook v1. 
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

mons_avail="$(find /home/"$(whoami)"/bin/litebook/ -type f -name "*hdmi-start.sh" | \
	sed 's/-hdmi-start.sh//' | sed "s|/home/$(whoami)/bin/litebook/||")"

# needed to call the current display
DISPLAY=:0
export DISPLAY
XAUTHORITY=/home/"$(whoami)"/.Xauthority
export XAUTHORITY

echo "Testing if HDMI is connected.  Please enter your password"
echo

hdmi_test="$(sudo -k get-edid | parse-edid | grep Identifier)"

# ensure that HDMI is plugged in
if [[ "${hdmi_test}" =~ "@" ]] ; then
	echo "HDMI must be plugged in to complete HDMI setup."
	echo "Please connect your HDMI device and select Continue."
	select cont in "Continue" "Exit" ; do
		case $cont in
			Continue ) 
				hdmi_test="$(sudo -k get-edid | parse-edid | grep Identifier)"
				if [[ "${hdmi_test}" =~ "@" ]] ; then
					echo
					echo "HDMI device not found."
				else
					echo
					echo "HDMI device found.  Continuing setup."
					break
				fi
				;;
			Exit ) 
				echo "Exiting the HDMI startup process."
				exit 0
				;;
			* )
				echo "That selection is invalid.  Please choose Continue or Exit."
				;;
		esac
	done
fi

# determine the monitor we're plugging into
while true ; do
	echo "The monitors available are: ${mons_avail}"
	read -p "which monitor do you want to use : " mon_used
	if [[ "${mon_used}" =~ ${mons_avail} ]] ; then
		echo
		echo "${mon_used} selected.  Continuing to activation." ;
		break
	else
		echo
		echo "That selection is invalid.  Please choose a listed monitor."
	fi		
done

# establish HDMI screen position
echo
echo "Now to position the HDMI output.  
Do you want to mirror or extend the Litebook screen?"
echo
select pos in "Mirror-display" "Extend-right" "Extend-down" ; do
	case $pos in
		Mirror-display ) 
			echo "Mirroring current display"
			mon_pos="m"
			break
			;;
		Extend-right ) 
			echo "Extending current display to the right"
			mon_pos="r"
			break
			;;
		Extend-down ) 
			echo "Extending current display downwards"
			mon_pos="d"
			break
			;;
		* )
			echo "That position is invalid.  Please choose a listed position"
			;;
	esac
done

# set the position and magnification (mag uses known working values based on position)
if [[ "${mon_pos}" == "m" ]] ; then
	sed -i "s/--POS/--same-as eDP1/" /home/"$(whoami)"/bin/litebook/"${mon_used}"-hdmi-start.sh
	sed -i "s/--TRANS/--transform 1.05,0,0,0,1.05,0,0,0,1/" /home/"$(whoami)"/bin/litebook/"${mon_used}"-hdmi-start.sh
elif [[ "${mon_pos}" == "r" ]] ; then
	sed -i "s/--POS/--right-of eDP1/" /home/"$(whoami)"/bin/litebook/"${mon_used}"-hdmi-start.sh
	sed -i "s/--TRANS/--transform 1.1,0,0,0,1.1,0,0,0,1/" /home/"$(whoami)"/bin/litebook/"${mon_used}"-hdmi-start.sh
else
	sed -i "s/--POS/--below eDP1/" /home/"$(whoami)"/bin/litebook/"${mon_used}"-hdmi-start.sh
	sed -i "s/--TRANS/--transform 1.1,0,0,0,1.1,0,0,0,1/" /home/"$(whoami)"/bin/litebook/"${mon_used}"-hdmi-start.sh
fi

# activate the display
source /home/"$(whoami)"/bin/litebook/"${mon_used}"-hdmi-start.sh

# wrap everything up
echo 
echo "HDMI setup is now complete.  All settings are stored in ~/bin/litebook/${mon_used}-hdmi-start.sh

${mon_used}-hdmi-start.sh will need to be executed upon every reboot, as xrandr does 
not retain settings on its own.  If you reboot, HDMI output _will not_ work without
running this script. 

If you have any overscan/underscan issues, they can be fixed by running
/etc/litebook-scripts/scripts/litebook-hdmi-output-adjuster.sh.

For further info, please consult /etc/litebook-scripts/info/litebook-hdmi-fixes.info"

exit 0
