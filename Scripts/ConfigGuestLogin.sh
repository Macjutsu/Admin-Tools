#!/bin/bash
# ConfigGuestLogin
# This script configures macOS for Guest account (auto)login.
# https://github.com/Macjutsu
# by Kevin M. White
# 2024/2/27

# MARK: *** Parameters ***
################################################################################

# The desired status of the Guest account, one of four states; ON | AUTO | OFF | "blank"
# ON = Guest account is enabled for standard login.
# AUTO = Guest account is enabled for automatic login.
# OFF or "blank" = Guest account is disabled for any login.
# This can be hard coded here or passed in via command line or Jamf Pro.
GUEST="${1}"

# In case passed in via Jamf Pro.
[[ $# -gt 3 ]] && GUEST="${4}"

# MARK: *** Functions ***
################################################################################

check_guest_status() {
guest_status="OFF"
[[ $(sysadminctl -guestAccount status 2>&1 | grep -c 'enabled') -gt 0 ]] && guest_status="ON"
}

check_guest_auto() {
guest_auto="OFF"
if [[ "${macos_version_major}" -ge 13 ]]; then
	[[ $(sysadminctl -autologin status 2>&1 | grep -c 'Guest') -gt 0 ]] && guest_auto="ON"
else # Legacy macOS method.
	[[ $(defaults read /Library/Preferences/com.apple.loginwindow autoLoginUser 2>/dev/null | grep -c 'Guest') -gt 0 ]] && guest_auto="ON"
fi
}

# MARK: *** Main ***
################################################################################

# Make sure script is running as root.
if [[ $(id -u) -ne 0 ]]; then
	echo "Error: This script must run with root privileges."
	exit 1
fi

# Validate ${GUEST} parameter status.
if [[ "${GUEST}" =~ ^ON$ ]]; then
	echo "Status: Requested configuration is to enable the Guest account for standard login."
elif [[ "${GUEST}" =~ ^AUTO$ ]]; then
	echo "Status: Requested configuration is to enable the Guest account for automatic login."
elif [[ "${GUEST}" =~ ^OFF$ ]] || [[ -z $GUEST ]]; then
	echo "Status: Requested configuration is to disable the Guest account."
else
	echo "Error: Unrecognized configuration option: ${GUEST}"
	echo "Error: Supported options are: ON | AUTO | OFF | 'blank'"
	exit 1
fi

# Validate FileVault status.
if [[ $(fdesetup status 2>&1 | grep -c 'On') -gt 0 ]] && [[ "${GUEST}" == "AUTO" ]]; then
	echo "Error: Can not configure automatic login because FileVault is enabled."
	exit 1
fi

# Get the macOS version.
macos_version_major=$(sw_vers -productVersion | cut -d'.' -f1) # Expected output: 10, 11, 12

# Wait for Setup Assistant to complete.
setup_assistant_process=$(pgrep -l "Setup Assistant")
until [[ -z "${setup_assistant_process}" ]]; do
	echo "Status: Waiting for Setup Assitant to complete."
	sleep 1
	setup_assistant_process=$(pgrep -l "Setup Assistant")
done

# Check for the current Guest account status.
check_guest_status
check_guest_auto

# If requested, make sure the Guest account is enabled for standard login.
if [[ "${GUEST}" =~ ^ON$|^AUTO$ ]]; then
	if [[ "${guest_status}" == "OFF" ]]; then
		echo "Status: Enabaling Guest account."
		sysadminctl -guestAccount on >/dev/null 2>&1
		check_guest_status
	fi
	if [[ "${guest_status}" == "ON" ]]; then
		echo "Status: Guest account is enabled."
	else
		echo "Error: Could not enable Guest account."
		exit 1
	fi
	# If requested, make sure the Guest account is also enabled for automatic login.
	if [[ "${GUEST}" =~ ^AUTO$ ]]; then
		if [[ "${guest_auto}" == "OFF" ]]; then
			echo "Status: Enabaling Guest account for automatic login."
			if [[ "${macos_version_major}" -ge 13 ]]; then
				sysadminctl -autologin set -userName "Guest" -password "" >/dev/null 2>&1
			else # Legacy macOS method.
				defaults write /Library/Preferences/com.apple.loginwindow autoLoginUser -string "Guest" >/dev/null 2>&1
			fi
			check_guest_auto
		fi
		if [[ "${guest_auto}" == "ON" ]]; then
			echo "Status: Guest account is enabled for automatic login."
		else
			echo "Error: Could not enable Guest account for automatic login."
			exit 1
		fi
	else # Guest account should not be enabled for automatic login.
		if [[ "${guest_auto}" == "ON" ]]; then
			echo "Status: Disabaling Guest account for automatic login."
			if [[ "${macos_version_major}" -ge 13 ]]; then
				sysadminctl -autologin off >/dev/null 2>&1
			else # Legacy macOS method.
				defaults delete /Library/Preferences/com.apple.loginwindow autoLoginUser >/dev/null 2>&1
			fi
			check_guest_auto
		fi
		if [[ "${guest_auto}" == "OFF" ]]; then
			echo "Status: Guest account is disabled for automatic login."
		else
			echo "Error: Could not disable Guest account for automatic login."
			exit 1
		fi
	fi
else # Guest account should be disabled.
	if [[ "${guest_auto}" == "ON" ]]; then
		echo "Status: Disabaling Guest account for automatic login."
		if [[ "${macos_version_major}" -ge 13 ]]; then
			sysadminctl -autologin off >/dev/null 2>&1
		else # Legacy macOS method.
			defaults delete /Library/Preferences/com.apple.loginwindow autoLoginUser >/dev/null 2>&1
		fi
		check_guest_auto
	fi
	if [[ "${guest_status}" == "ON" ]]; then
		echo "Status: Disabaling Guest account."
		sysadminctl -guestAccount off >/dev/null 2>&1
		check_guest_status
	fi
	if [[ "${guest_status}" == "OFF" ]] && [[ "${guest_auto}" == "OFF" ]]; then
		echo "Status: Guest account is disabled."
	else
		[[ "${guest_status}" == "ON" ]] && echo "Error: Could not disable Guest account."
		[[ "${guest_auto}" == "ON" ]] && echo "Error: Could not disable Guest account for automatic login."
		exit 1
	fi
fi


exit 0
