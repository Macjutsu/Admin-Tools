#!/bin/bash

# Specific file to look for.
FILE_PATH="/var/db/.AppleSetupDone"

# Report if the file exists.
if [[ -f "${FILE_PATH}" ]]; then
	ls_date=$(ls -la -T "${FILE_PATH}" | awk '{print $9"-"$6"-"$7" "$8}')
	# Report if the file has a value.
	if [[ "${ls_date}" != "" ]]; then
		jamf_date=$(date -j -f "%Y-%b-%d %H:%M:%S" "${ls_date}" +"%Y-%m-%d %H:%M:%S")
		echo "<result>${jamf_date}</result>"
	else
		echo "<result>False</result>"
	fi
else
	echo "<result>False</result>"
fi

exit 0
