#!/bin/bash
# This Jamf Pro Extension Attribute reports if the computer is capable of performing the Erase All Contents And Settings action.

if [[ $(arch) == "arm64" ]]; then # Mac computer with Apple Silicon.
	echo "<result>True</result>"
else # Mac computers with Intel.
	if [[ $(system_profiler SPiBridgeDataType | grep -c 'Apple T2') -gt 0 ]]; then
		if [[ $(sw_vers -productVersion | cut -d'.' -f1) -ge 12 ]]; then
			echo "<result>True</result>"
		else # Incompatible macOS version.
			echo "<result>True, incompatible macOS version</result>"
		fi
	else # Incompatible hardware.
		echo "<result>False</result>"
	fi
fi

exit 0
