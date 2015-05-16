#!/bin/bash
# Malscan installer - Authored by Josh Grancell
# Version 1.1.0 - Updated 5/14/2015

clear

## Getting the OS information
if [[ -f "/etc/redhat-release" ]]; then
	if grep -qs "CentOS" /etc/redhat-release; then
		DISTRO="CentOS"
		yum -y install epel-release
		yum -y install clamav git

		# CentOS 7 doesn't install freshclam by default, so we need to add in another package
		if grep -qs "release 7" /etc/redhat-release; then
			yum -y install clamav-update
			# We also need to manially identify the clamav path and the user
			CLAMAV_DIRECTORY=$(find / -name "daily.cvd" | xargs basename)
			CLAMAV_
	elif grep -qs "RedHat" /etc/redhat-release; then
		DISTRO="RHEL"
		yum -y install epel-release
		yum -y install clamav git
	else
		DISTRO="Unsupported"
		echo "The current Operating System Distribution is unsupported."
		echo "Only RedHat Enterprise Linux and CentOS are supported from the RHEL family."
		echo "Please submit a bug at https://github.com/jgrancell/Malscan/issues with the following output:"
		cat /etc/redhat-release
		exit 1
	fi
elif [[ -f /etc/lsb-release ]]; then
	/etc/lsb-release
	if [[ "$DISTRIB_ID" == "Ubuntu" ]]; then
		DISTRO="Ubuntu"
		apt-get -y install clamav git
	else
		DISTRO="UNSUPPORTED"
                echo "The current Operating System Distribution is unsupported."
                echo "Only Ubuntu is supported at this time from the Debian family."
                echo "Please submit a bug at https://github.com/jgrancell/Malscan/issues with the following output:"
                echo "Distro: $DISTRIB_ID / Release: $DISTRIB_RELEASE / Details: $DISTRIB_DESCRIPTION"
                exit 1
	fi
fi

#clear

## Getting directory names
if [[ -z $CLAMAV_DIRECTORY ]]; then
	CLAMAV_DIRECTORY=$(grep "DatabaseDirectory" /etc/freshclam.conf | awk '{print $2}')
fi

CLAMAV_USER=$(ls -ld "$CLAMAV_DIRECTORY" | awk '{print $3}')

CLAMSCAN=$(find / -name "clamscan" -executable -path "*bin*")
FRESHCLAM=$(find / -name "freshclam" -executable -path "*bin*")

## Creating the Malscan directory
mkdir -p /usr/local/share/malscan
cd /usr/local/share/malscan
MAIN_DIRECTORY="/usr/local/share/malscan"

## Bringing down the git repository
git clone https://github.com/jgrancell/Malscan.git
rsync -aqzP /usr/local/share/malscan/Malscan/ /usr/local/share/malscan/
rm -rf ./Malscan

## Echoing the beginning of the configuration file
{
echo "#!/bin/bash"
echo "# Malscan Main Configuration File"
echo "# Autogenerated by install.sh since Version 1.5.0"
echo ""
echo ""
echo "# Directory and User Structure"
echo "CLAMAV_DIRECTORY=\"$CLAMAV_DIRECTORY\""
echo "MALSCAN_DIRECTORY=\"$MAIN_DIRECTORY\""
echo "MALSCAN_USER=\"$CLAMAV_USER\""
echo "MALSCAN_BINARY_LOCATION=\"/usr/local/bin/malscan\""
echo "CLAMSCAN_BINARY_LOCATION=\"$CLAMSCAN\""
echo "FRESHCLAM_BINARY_LOCATION=\"$FRESHCLAM\""
} >> conf.malscan

#clear

## Getting the user's input on email notifications
echo -e "\033[33mBeginning the malscan configuration process..."
echo -ne "Would you like to enable email notifications? [Y/n] \033[37m"
read EMAIL_NOTIFICATIONS

if [[ "$EMAIL_NOTIFICATIONS" == "y" || "$EMAIL_NOTIFICATIONS" == "Y" || "$EMAIL_NOTIFICATIONS" == "yes" || "$EMAIL_NOTIFICATIONS" == "YES" ]]; then
	## Email notifications are being enabled, so we're now getting the list of addresses
	echo -e "\033[33mAt what email addresses would you like to receive notifications (Comma-separated list): \033[37m"
	read EMAIL_ADDRESSES

	## Echoing the formatted configuration information to the file
	{
	echo "ENABLE_EMAIL_NOTIFICATIONS=\"1\"" >> conf.malscan
	echo "NOTIFICATION_ADDRESSES=\"$EMAIL_ADDRESSES\""
	echo ""
	} >> conf.malscan
else 
	## Email notifications are not being enabled. Echoing default disabled information.
	{
	echo "ENABLE_EMAIL_NOTIFICATIONS=\"0\"" >> conf.malscan
	echo "NOTIFICATION_ADDRESSES=\"\"" >> conf.malscan
	echo ""
	} >> conf.malscan
fi

## Echoing the spacer for the quarantine section into the configuration file
echo "# Quarantine and Logging" >> conf.malscan

## Prompting for 
echo -ne "\033[33mWould you like to enable remote quarantining of malicious files through SSH and rsync? [y/N] [default: N] \033[37m"
read REMOTE_QUARANTINE

if [[ "$REMOTE_QUARANTINE" == "Y" || "$REMOTE_QUARANTINE" == "y" || "$REMOTE_QUARANTINE" == "YES" || "$REMOTE_QUARANTINE" == "yes" ]]; then 
	## We are setting up Remote Quarantine, so requesting that information here
	echo -e "\033[33mWhat is the IP Address or FQDN of the server you would like to use for quarantine? \033[37m"
	read SERVER
	echo -e "\033[33mWhat is the username of the account on the remote server you will connect with via SSH? \033[37m"
	read USER
	echo -e "\033[33mWhat is the full path of the directory you would like to quarantine files in on the remote server? \033[37m"
	read QUARANTINE_PATH
	
	## We're giving the information back to them and notifying them to set up SSH keys
	echo "The chosen connection information is \033[32m$USER@$SERVER:$QUARANTINE_PATH\033[37m. Please set a private key for the root user on this server, and add the public key to the authorized_key file for the remote server's user "
	
	## Echoing the remote information into the configuration file
	{
	echo "REMOTE_QUARANTINE_ENABLED=\"1\""
	echo "REMOTE_SSH=\"$USER@$SERVER\""
	echo "QUARANTINE_PATH=\"$QUARANTINE_PATH\""
	} >> conf.malscan
else
	## No remote quarantine, so we're now requesting the local quarantine directory
	echo -e "\033[33mWhat directory would you like to quarantine files in? [default=/usr/local/share/malscan/quarantine] \033[37m"
	read QUARANTINE_PATH

	## Creating the quarantine path if it doesn't exist
	if [[ -d "$QUARANTINE_PATH" ]]; then
		echo -e "\033[32mYour quarantine path has been successfully set!\033[37m"
	else 
		mkdir -p "$QUARANTINE_PATH"
		echo -e "\033[32mThe directory $QUARANTINE_PATH has been created, and set as the Quarantine location.\033[37m"
	fi
	
	## Echoing the local quarantine inforamtion into the configuration file.
	{
	echo "REMOTE_QUARANTINE_ENABLED=\"0\""
	echo "REMOTE_SSH=\"\""
	echo "QUARANTINE_PATH=\"$QUARANTINE_PATH\""
	} >> conf.malscan

fi

## Echoing the remaining information into the configuration file.
{
echo "REMOTE_LOGGING=\"0\"" >> conf.malscan #This is not currently used
echo ""
echo "# Static Whitelist"
echo "AVSCAN_WHITELIST=\"'quarantine'\""
echo "MIME_WHITELIST=\"\""
echo ""
echo "# String Length Scanning"
echo "LENGTH_MINIMUM=15000"
} >> conf.malscan

## Beginning the signature update process.
#clear
echo -e "\033[032mMalscan has been successfully configured! Beginning initial update...\033[37m"
wget -q https://www.rfxn.com/downloads/rfxn.hdb
wget -q https://www.rfxn.com/downloads/rfxn.ndb
wget -q https://repo.joshgrancell.com/custom.hdb
wget -q https://repo.joshgrancell.com/custom.ndb

"$FRESHCLAM" >> /dev/null

mkdir -p /usr/local/share/malscan/log
ln -s /usr/local/share/malscan/malscan.sh /usr/local/bin/malscan

chown -R "$CLAMAV_USER":"$CLAMAV_USER" /usr/local/share/malscan

echo -ne "\033[32mMalware signatures have been updated successfully. Would you like to whitelist known clean files at this time? [Y/n] \033[37m"
read BEGIN_WHITELIST

if [[ "$BEGIN_WHITELIST" == "y" || "$BEGIN_WHITELIST" == "Y" || "$BEGIN_WHITELIST" == "yes" || "$BEGIN_WHITELIST" == "YES" ]]; then
	echo -e "\033[33mThe whitelist process will scan an entire file tree, including all subdirectories and files.\033[37m"
	echo -e "\033[33mBy whitelisting a file, it will not trigger any type of detection in its current state. Any type of alteration to the file once whitelisted will trigger a detection."
	echo -e "\033[33mAll files found within the file tree will be whitelisted. This is only recommended for known clean systems, such as default installs or imports from secure staging servers.\033[37m"
	echo -ne "\033[33mIf you would like to whitelist a specific directory, please provide the full directory path now. If you would like to cancel, type the word cancel: \033[37m"
	read WHITELIST_DIRECTORY

	if [[ "$WHITELIST_DIRECTORY" == "cancel" ]]; then
		echo -e "\033[33mWhitelisting has been cancelled. You can whitelist again at any time using the malscan program directly.\033[37m"
	else
		/usr/local/bin/malscan -w "$WHITELIST_DIRECTORY"
	fi
fi
echo "Malscan has been successfully configured and instantited."
/usr/local/bin/malscan -h
exit 0
