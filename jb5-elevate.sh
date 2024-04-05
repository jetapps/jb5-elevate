#!/bin/bash


# Script to prepare and fix JB5 after Elevate for situations where the stock AlmaLinux Elevate procedure is used. 
#
# If using a cPanel/WHM, we recommend using the official cPanel ELevate procedure instead at https://github.com/cpanel/elevate
#
# For testing purposes: sudo leapp answer --section remove_pam_pkcs11_module_check.confirm=True && leapp upgrade && reboot

LOG_FILE="/root/jb5-elevate.log"
POSTCRON="/etc/cron.d/jetbackup5-elevate"

pre_flag=false
post_flag=false
script_path=$(realpath "${0}")
JB_TIER="$(jetbackup5 --version 2>/dev/null | sed "2 d" | awk -F "|" '{print $2}' | grep -oP "(?<=Current Tier )[A-Z]+" | tr '[:upper:]' '[:lower:]')"

# Loop through arguments
elevate_step="$1"
case $elevate_step in
--pre)
  pre_flag=true
  ;;
--post)
  post_flag=true
  ;;
*)
  # Unknown flag
  echo "Usage: bash ${script_path} --pre or --post"
  exit 1
  ;;
esac

# Check if the --pre flag was provided
if $pre_flag; then
  echo "The --pre flag was provided. Performing Pre-Elevate steps to get JB5 ready for Elevate..."\
  echo "Removing jetphp81-zip..."

/usr/bin/rpm -e --nodeps jetphp81-zip

  echo ""
  echo "Adding @reboot cron to run this script automatically with --post flag..."
  echo ""
  echo "Cron File Location: ${POSTCRON}"

### Adding cron - runs this script with --post at next boot (hopefully after elevate, but we can't control that in this script)
cat >${POSTCRON} <<EOF
@reboot root ${script_path} --post 2>/dev/null 
EOF
###

  echo ""
  echo  "JetBackup 5 ready for Elevate. To view the logs for this script after you've rebooted (when prompted by leapp-upgrade), view the /root/jb5-elevate.log file."
  echo "Pre-Elevate Steps done. Script will run at next boot. Try checking back later." >>${LOG_FILE}
  echo "Done."
exit 0

elif $post_flag; then

exec 3>&1 1> >(tee -a ${LOG_FILE}) 2>&1

  echo "The --post flag was provided. Performing Post-Elevate steps..."
  echo "Installing jetphp81-zip..."
yum -y install jetphp81-zip --disablerepo=* "--enablerepo=jetapps,jetapps-${JB_TIER}"
[[ "$?" -eq 0 ]] && echo "jetphp81-zip successfully reinstalled." || echo "Error occurred during yum install. Please contact support@jetapps.com."
  echo "Upgrading packages..."
yum -y update 'jet*' --disablerepo=* "--enablerepo=jetapps,jetapps-${JB_TIER}"
[[ "$?" -eq 0 ]] && echo "Done! JetBackup 5 upgraded to proper EL-8 Packages." || echo "Error occurred during yum update. Please contact support@jetapps.com."
  echo "Cleaning up cron file..."
rm -- "${POSTCRON}"

  echo  "Done!"
fi

exit 0
