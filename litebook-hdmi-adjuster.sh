#!/bin/bash -

#   Name    :   litebook-hdmi-adjuster.sh
#   Author  :   Richard Buchanan II for Alpha Universal, LLC
#   Brief   :   A script to fix HDMI underscan/overscan issues
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

# finds all HDMI monitor scripts installed in ~/bin/litebook, and strips their
# extensions and file paths
mons_avail="$(find /home/"$(whoami)"/bin/litebook/ -type f -name "*hdmi-start.sh" | \
	sed s/-hdmi-start.sh// | sed "s|/home/$(whoami)/bin/litebook/||")"

# vars for setting or skipping pixel adjustments
px_count=0
px_skip=""

# needed to call the current display
DISPLAY=:0
export DISPLAY
XAUTHORITY=/home/"$(whoami)"/.Xauthority
export XAUTHORITY

echo "Testing if HDMI is connected Please enter your password"
echo

hdmi_test="$(sudo -k get-edid | parse-edid | grep Identifier)"

# ensure that HDMI is plugged in
if [[ "${hdmi_test}" =~ "@" ]] ; then
	echo "HDMI must be plugged in to complete HDMI setup."
	echo "Please connect your HDMI device and select Continue."
	select cont in "Continue" "Exit" ; do
		case $cont in
			Continue ) 
				# reload the var
				hdmi_test="$(sudo -k get-edid | parse-edid | grep Identifier)"
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

# determine the monitor we're plugging into
while true ; do
	echo "The monitors available are: ${mons_avail}"
	read -p "which monitor do you want to use : " mon_used
	if [[ "${mon_used}" =~ ${mons_avail} ]] ; then
		echo "${mon_used} selected.  Continuing to activation." ;
		break
	else
		echo "That selection is invalid.  Please choose a listed monitor."
	fi		
done

# create a safe copy of existing HDMI start script, used to test transformations
# until user is happy with the result
cp /home/"$(whoami)"/bin/litebook/"${mon_used}"-hdmi-start.sh \
	/home/"$(whoami)"/bin/litebook/"${mon_used}"-hdmi-start.tmp
chmod +x /home/"$(whoami)"/bin/litebook/"${mon_used}"-hdmi-start.tmp

# grab resolution and position, now that we know which monitor is used
mon_res="$(grep -Eo "[0-9]{1,16}x[0-9]{1,16}" /home/"$(whoami)"/bin/litebook/"${mon_used}"-hdmi-start.tmp | uniq)"
mon_pos="$(grep transform /home/"$(whoami)"/bin/litebook/"${mon_used}"-hdmi-start.tmp | awk '{ print $8, $9 }')"

# transform vars for testing and keeping results, respectively
tmp_trans="$(grep transform /home/"$(whoami)"/bin/litebook/"${mon_used}"-hdmi-start.tmp | awk '{ print $7 }')"
replaced_trans="$(grep transform /home/"$(whoami)"/bin/litebook/"${mon_used}"-hdmi-start.sh | awk '{ print $7 }')"

# establish adjustment vars, now that monitor has been determined
x_pos="$(echo "${mon_trans}" | cut -d "," -f 3)"
y_pos="$(echo "${mon_trans}" | cut -d "," -f 6)"
x_mag="$(echo "${mon_trans}" | cut -d "," -f 1)"
y_mag="$(echo "${mon_trans}" | cut -d "," -f 5)"
old_x=""
old_y=""
old_x_mag=""
old_y_mag=""

# adjustment vars for resetting all adjustments
orig_x="$(echo "${mon_trans}" | cut -d "," -f 3)"
orig_y="$(echo "${mon_trans}" | cut -d "," -f 6)"
orig_x_mag="$(echo "${mon_trans}" | cut -d "," -f 1)"
orig_y_mag="$(echo "${mon_trans}" | cut -d "," -f 5)"

# set directional vars and determine a human-readable direction
# left and down are negative transform values, while right and up are positive
lr_dir=""
ud_dir=""
until [ -n "${lr_dir}" -a -n "${ud_dir}" ] ; do
	if [[ "${x_pos}" == 0 ]] ; then
		lr_dir=" pixels left/right."
	fi
	if [[ "${y_pos}" == 0 ]] ; then
		ud_dir=" pixels up/down." 
	fi
	if [[ -n "$(echo "${x_pos}"|  grep '-')" ]] ; then
		lr_dir="pixels to the left"
	fi
	if [[ -n "$(echo "${y_pos}" | grep '-')" ]] ; then 
		ud_dir=" pixels down"
	fi
	if [[ -z "$(echo "${x_pos}" | grep '-')" ]] && [[ "${x_pos}" -ne 0 ]] ; then
		lr_dir=" pixels to the right" 
	fi
	if [[ -z "$(echo "${y_pos}" | grep '-')" ]] && [[ "${y_pos}" -ne 0 ]] ; then 
		ud_dir=" pixels up" 
	fi
done

# state existing transformations
echo
echo "the ${mon_used} monitor currently has the following adjustments:"
echo "${x_mag} magnification."
echo "${x_pos} ${lr_dir}" 
echo "${y_pos} ${ud_dir}" 
echo

# enable user-specified transformations
while true ; do
	echo "Adjustments take place in three parts. 
	
	Pixels are specified first, direction second, and magnification last. 
	
	If your desktop fits within the HDMI monitor, but your mouse hits an
	invisible boundary before the physical edge, then select to only adjust
	the magnification"
	echo
	echo "Set the pixels to be shifted:"
	select adj in "5px" "10px" "15px" "20px" "Skip-to-magnification" ; do
		case $adj in
			5px ) 
				echo "5px set"
				px_count=5
				break
				;;
			10px ) 
				echo "10px set"
				px_count=10
				break
				;;
			15px ) 
				echo "15px set"
				px_count=15
				break
				;;
			20px ) 
				echo "20px set"
				px_count=20
				break
				;;
			Skip-to-magnification )
				echo "Skipping pixel adjustments"
				px_skip="1"
				break
				;;
			* )
				echo "That selection is invalid.  Please choose a listed selection"
				;;
		esac
	done
	if [[ "${px_skip}" -ne 1 ]] ; then
		echo "Set the direction to shift:"
		select pos in "Left" "Right" "Up" "Down" ; do 
			case $pos in 
				Left ) 
					echo "Adjusting left by ${px_count} pixels"
					old_x="${x_pos}"
					x_pos=$(bc <<< "${x_pos}"-"${px_count}")
					break
					;;
				Right ) 
					echo "Adjusting right by ${px_count} pixels"
					old_x="${x_pos}"
					x_pos=$(bc <<< "${x_pos}"+"${px_count}")
					break
					;;
				Up ) 
					echo "Adjusting up by ${px_count} pixels"
					old_y="${y_pos}"
					y_pos=$(bc <<< "${y_pos}"+"${px_count}")
					break
					;;
				Down ) 
					echo "Adjusting down by ${px_count} pixels"
					old_y="${y_pos}"
					y_pos=$(bc <<< "${y_pos}"-"${px_count}")
					break
					;;
				* )
					echo "That selection is invalid.  Please choose a listed selection"
					;;
			esac
		done
	fi
	echo "Set the magnification:"
	select mag in "0.05" "0.1" "-0.05" "-0.1" "Skip-to-finish"; do 
		case $mag in 
			0.05 )
				echo "Increasing magnification by 0.05"
				old_x_mag="${x_mag}"
				old_y_mag="${y_mag}"
				x_mag=$(bc <<< "${x_mag}"+0.05)
				y_mag=$(bc <<< "${y_mag}"+0.05)
				break
				;;
			0.1 )
				echo "Increasing magnification by 0.1"
				old_x_mag="${x_mag}"
				old_y_mag="${y_mag}"
				x_mag=$(bc <<< "${x_mag}"+0.1)
				y_mag=$(bc <<< "${y_mag}"+0.1)
				break
				;;
			-0.05 )
				echo "Reducing magnification by 0.05"
				old_x_mag="${x_mag}"
				old_y_mag="${y_mag}"
				x_mag=$(bc <<< "${x_mag}"-0.05)
				y_mag=$(bc <<< "${y_mag}"-0.05)
				break
				;;
			-0.1 )
				echo "Reducing magnification by 0.1"
				old_x_mag="${x_mag}"
				old_y_mag="${y_mag}"
				x_mag=$(bc <<< "${x_mag}"-0.1)
				y_mag=$(bc <<< "${y_mag}"-0.1)					
				break
				;;
			Skip-to-finish )
				echo "Skipping magnification adjustments"
				old_x_mag="${x_mag}"
				old_y_mag="${y_mag}"
				break
				;;
			* )
				echo "That selection is invalid.  Please choose a listed selection"
				;;
		esac
	done	

# apply transformations
	test_trans="${x_mag}",0,"${x_pos}",0,"${y_mag}","${y_pos}",0,0,1
	echo "Applying specified transformations"
	sed -i "s/${tmp_trans}/${test_trans}/" /home/"$(whoami)"/bin/litebook/"${mon_used}"-hdmi-start.tmp	
	cd /home/"$(whoami)"/bin/litebook/ && ./"${mon_used}"-hdmi-start.tmp

# confirm results, quit, or enable further adjustments
	echo "Would you like to make more adjustments, keep this result, 
	reset adjustments, revert adjustments, undo adjustments, or quit? 
	
	* More-adjustments does just as it says.
	* Keep-results will exit and save all changes.
	* Quit will exit _without_ saving.
	
	* Revert-adjustments rolls your adjustments back by one level.
	* Reset-adjustments returns adjustments to their starting point.
	* Undo-adjustments changes all directional adjustments to zero.  	
	
	Changes will _not_ be saved until Keep-result is selected."
	echo
	select resp in "More-adjustments" "Keep-results" "Revert-adjustments" \
	"Reset-adjustments" "Undo-adjustments" "Quit" ; do
		case $resp in 
			More-adjustments)
				echo "Enabling further adjustments."	
				break
				;;
			Keep-results)
				echo "OK, keeping specified adjustments."
				sed -i "s/${replaced_trans}/${test_trans}/" /home/"$(whoami)"/bin/litebook/"${mon_used}"-hdmi-start.sh	
				exit 0
				;;			
			Revert-adjustments)
				echo "Reverting adjustments to their previous state."
				x_pos="${old_x}"
				y_pos="${old_y}"
				x_mag="${old_x_mag}"
				y_mag="${old_y_mag}"
				test_trans="${x_mag}",0,"${x_pos}",0,"${y_mag}","${y_pos}",0,0,1
				sed -i "s/${tmp_trans}/${test_trans}/" /home/"$(whoami)"/bin/litebook/"${mon_used}"-hdmi-start.tmp	
				cd /home/"$(whoami)"/bin/litebook/ && ./"${mon_used}"-hdmi-start.tmp
				break
				;;
			Reset-adjustments)
				echo "Resetting adjustments to their starting point."
				x_pos="${orig_x}"
				y_pos="${orig_y}"
				x_mag="${orig_x_mag}"
				y_mag="${orig_y_mag}"
				test_trans="${orig_x_mag}",0,"${orig_x}",0,"${orig_y_mag}","${orig_y}",0,0,1
				sed -i "s/${tmp_trans}/${test_trans}/" /home/"$(whoami)"/bin/litebook/"${mon_used}"-hdmi-start.tmp	
				cd /home/"$(whoami)"/bin/litebook/ && ./"${mon_used}"-hdmi-start.tmp
				break
				;;
			Undo-adjustments)
				echo "Undoing all adjustments and returning to a clean slate."
				x_pos=0
				y_pos=0
				x_mag=0
				y_mag=0
				test_trans="${x_mag}",0,"${x_pos}",0,"${y_mag}","${y_pos}",0,0,1
				sed -i "s/${tmp_trans}/${test_trans}/" /home/"$(whoami)"/bin/litebook/"${mon_used}"-hdmi-start.tmp	
				cd /home/"$(whoami)"/bin/litebook/ && ./"${mon_used}"-hdmi-start.tmp
				break
				;;
			Quit)
				echo "Quitting HDMI adjustment script without saving changes."
				exit 0
				;;
			* )
				echo "That selection is invalid.  Please choose a listed selection"
				;;			
		esac
	done
done

exit 0
