#!/bin/bash -

#   Name    :   litebook-hdmi-setup.sh
#   Author  :   Richard Buchanan II for Alpha Universal, LLC
#   Brief   :   A script that sets up all needed components to
#				force HDMI output on the Litebook v1. 
#

set -o errexit      # exits if non-true exit status is returned
set -o nounset      # exits if unset vars are present

# fail if not running as root
if [[ $EUID -ne 0 ]] ; then
	echo "This is the _only_ litebook-hdmi script that requires root privileges." ;
	echo "Please re-run this script with sudo." ;
	exit 1 ;
fi

PATH=/usr/local/bin:/usr/bin:/bin:/sbin:/usr/sbin:/usr/local/sbin

cur_user="$(who | grep ":0" | cut -f 1 -d ' ' | uniq)"

# needed to call the current display
DISPLAY=:0
export DISPLAY
XAUTHORITY=/home/"${cur_user}"/.Xauthority
export XAUTHORITY

# install needed packages, if not already present
if [[ ! -x /usr/bin/parse-edid ]] ; then
    echo "Installing needed components"
    apt update && apt install -y read-edid
fi

# establish HDMI conf file name
while true ; do
	read -p "Please enter a one-word nickname for your monitor. 
	Multiple words can be used with underscores. : " mon_nick
	if [[ "$(echo "${mon_nick}" | wc -w)" == 1 ]] ; then
		break
	else
		echo "The monitor nickname must be one word or separated by underscores"
	fi
done
echo
echo "${mon_nick} assigned.  Continuing setup.
Testing if HDMI is connected"
echo

# create safe copy of HDMI conf file
cp /etc/litebook-scripts/scripts/hdmi/99-hdmi-xorg-template.txt \
	/etc/litebook-scripts/scripts/hdmi/99-"${mon_nick}"-hdmi.tmp

# begin configuring final HDMI startup script
if [[ ! -d /home/"${cur_user}"/bin/litebook ]] ; then
	sudo -u "${cur_user}" mkdir -p /home/"${cur_user}"/bin/litebook
fi
sudo -u "${cur_user}" cp /etc/litebook-scripts/scripts/hdmi/litebook-hdmi-template.sh \
	/home/"${cur_user}"/bin/litebook/"${mon_nick}"-hdmi-start.sh
sudo -u "${cur_user}" cp /etc/litebook-scripts/scripts/hdmi/litebook-hdmi-stop.sh \
	/home/"${cur_user}"/bin/litebook/
chown "${cur_user}":"${cur_user}" /home/"${cur_user}"/bin/litebook/litebook-hdmi-stop.sh

# var to establish HDMI status, now that read-edid is installed
hdmi_test="$(get-edid | parse-edid | grep Identifier | grep @ || echo "")"

# ensure that HDMI is plugged in
if [[ -n "${hdmi_test}" ]] ; then
	echo "HDMI must be plugged in to complete HDMI setup."
	echo "Please connect your HDMI device and select Continue."
	select cont in "Continue" "Exit" ; do
		case $cont in
			Continue ) 
				hdmi_test="$(get-edid | parse-edid | grep Identifier)"
				if [[ "${hdmi_test}" =~ "@" ]] ; then
					echo "HDMI device not found."
				else
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

# grab HDMI monitor EDID, and place findings in usr and xorg.conf.d
mkdir -p /usr/litebook/hdmi-edids
echo "Gathering ${mon_nick} monitor information"
echo


get-edid > /usr/litebook/hdmi-edids/"${mon_nick}".bin
sed -i "s|edids/|edids/${mon_nick}.bin|" /etc/litebook-scripts/scripts/hdmi/99-"${mon_nick}"-hdmi.tmp

# monitor-specific vars
edid_used="/usr/litebook/hdmi-edids/${mon_nick}.bin"
disp_size="$(parse-edid < "${edid_used}" | grep DisplaySize | cut -d " " -f 2,3)"
# determine specific modeline needed
pref_mode="$(parse-edid < "${edid_used}" | grep PreferredMode | grep -Eo "Mode "[0-9][0-9]"")"
# apply only the modeline values 
mlines="$(parse-edid < "${edid_used}" | grep -m 1 "${pref_mode}" | \
	awk '{ for (i=4; i<=NF; ++i) { printf("%s ", $i); } print "" }')"

# determine resolution
echo "Finishing setup."
echo
echo "Is the default resolution of 1920x1080 acceptable for your monitor?"
select yn in "Yes" "No" ; do
	case $yn in 
		Yes )
			echo "OK, using 1920x1080 as the resolution."
			cust_res=""
			break
			;;
		No ) 
			echo "Enabling custom resolution"
			cust_res=1
			break
			;;
		* )
			echo "That selection is invalid.  Please choose Yes or No."
			;;
	esac
done

if [[ "${cust_res}" == 1 ]] ; then
	while true ; do
	read -p "What is the monitor resolution?  Please enter as 1234x5678 : " mon_res
		if [[ -n "$(echo "${mon_res}" | grep -E "[0-9]x[0-9]")" ]] ; then
			echo "OK, using ${mon_res} as the new resolution"
			break
		else
			echo "That resolution is invalid.  Please enter as 1234x5678"
			read -p "What is the monitor resolution?  Please enter as 1234x5678 : " mon_res
		fi
	done
fi

# modify base HDMI config
sed -i "s/DisplaySize /DisplaySize ${disp_size}/" /etc/litebook-scripts/scripts/hdmi/99-"${mon_nick}"-hdmi.tmp
sed -i "s/Modeline \"1920x1080_60.00\"/Modeline \"1920x1080_60.00\" ${mlines}/" /etc/litebook-scripts/scripts/hdmi/99-"${mon_nick}"-hdmi.tmp
if [[ -n "${cust_res}" ]] ; then
	sed -i "s/1920x1080_60.00/${cust_res}_60.00/g" /etc/litebook-scripts/scripts/hdmi/99-"${mon_nick}"-hdmi.tmp ;
	sed -i "s/1920x1080/${cust_res}/g" /home/"${cur_user}"/bin/litebook/"${mon_nick}"-hdmi-start.sh ;
fi	

# install finished HDMI and eDP templates into xorg.conf.d
mv /etc/litebook-scripts/scripts/hdmi/99-"${mon_nick}"-hdmi.tmp \
	/etc/X11/xorg.conf.d/99-"${mon_nick}"-hdmi.conf
cp /etc/litebook-scripts/scripts/hdmi/99-edp-monitor.conf \
	/etc/X11/xorg.conf.d/99-edp-monitor.conf

# wrap everything up
echo 
echo "HDMI is now set up, but requires a system restart to be usable.  
After restarting, you must run /etc/litebook-scripts/scripts/hdmi/litebook-hdmi-start.sh 
to enable HDMI output."  

exit 0
