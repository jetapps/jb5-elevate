#!/bin/bash


# Script to prepare and fix JB5 after Elevate for situations where the stock AlmaLinux Elevate procedure is used. 
#
# If using a cPanel/WHM, we recommend using the official cPanel ELevate procedure instead at https://github.com/cpanel/elevate
#
# For testing purposes: sudo leapp answer --section remove_pam_pkcs11_module_check.confirm=True && leapp upgrade && reboot

# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
# THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED
# AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE,
# EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


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
  echo "The --pre flag was provided. Performing Pre-Elevate steps to get JB5 ready for Elevate..."
  echo "Removing jetphp81-zip..."

/usr/bin/rpm -e --nodeps jetphp81-zip

  echo ""
  echo "Adding @reboot cron to run this script automatically with --post flag..."
  echo "Cron File Location: ${POSTCRON}"

### Adding cron - runs this script with --post at next boot (hopefully after elevate, but we can't control that in this script)
cat >${POSTCRON} <<EOF
@reboot root ${script_path} --post 2>/dev/null 
EOF
###

echo ""
# Replace GPG Key with 4096 version for AL9 Elevate. 
echo "Replacing GPG Key with 4096 version in /etc/yum.repos.d/jetapps.repo ..."
sed -i 's/\bRPM-GPG-KEY-JETAPPS(?!-4096)\b/RPM-GPG-KEY-JETAPPS-4096/g' /etc/yum.repos.d/jetapps.repo

echo ""
  echo  "JetBackup 5 ready for Elevate. To view the logs for this script after you've rebooted (when prompted by leapp-upgrade), view the /root/jb5-elevate.log file."
  echo "Pre-Elevate Steps done. Script will run at next boot. Try checking back later." >>${LOG_FILE}
  echo "Done."
exit 0

elif $post_flag; then

exec 3>&1 1> >(tee -a ${LOG_FILE}) 2>&1

  echo "The --post flag was provided. Performing Post-Elevate steps..."
# Network can be lost by Elevate due to network-scripts deprecation in EL9. This exits rather than trying to install packages when network is unavailable. 
  echo "Verifying network is online..."
network_chk=$(curl -sS "https://ifconfig.me" -o /dev/null ; echo $?)
if [[ "${network_chk}" -ne 0 ]]; then
echo "[ABORTED] Problems with network connectivity. ** Postponing until next boot. **"
echo "If necessary, you can run the script again with the --post flag after the network problem is resolved."
exit 1
fi
  echo "Installing jetphp81-zip..."
yum -y install jetphp81-zip --disablerepo=* "--enablerepo=jetapps,jetapps-${JB_TIER}"
[[ "$?" -eq 0 ]] && echo "jetphp81-zip successfully reinstalled." || echo "Error occurred during yum install. Please contact support@jetapps.com."
  echo "Upgrading packages..."
yum -y update 'jet*' --disablerepo=* "--enablerepo=jetapps,jetapps-${JB_TIER}"
[[ "$?" -eq 0 ]] && echo "Done! JetBackup 5 dependencies updated to AlmaLinux 8/9 Packages." || echo "Error occurred during yum update. Please contact support@jetapps.com."
  echo "Cleaning up cron file..."
[[ -f "${POSTCRON}" ]] && rm -- "${POSTCRON}" || echo "Skipped - jetbackup5-elevate cron file does not exist."

echo  "Done!"
fi

exit 0
