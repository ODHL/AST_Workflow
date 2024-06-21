#!/bin/bash

# FTP server credentials
FTP_SERVER="ftp-private.ncbi.nlm.nih.gov"
FTP_USERNAME="subftp"
FTP_PASSWORD="SniappegEtnurak3"

# FTP commands file
FTP_COMMANDS=$(mktemp)
cat << EOF > "$FTP_COMMANDS"
cd uploads/samantha.sevilla_nih.gov_eymkOQSE
mkdir new_folder
cd new_folder
prompt
mput *gz
quit                           # Quit FTP session
EOF

# Connect to FTP server and execute commands
#lftp -u $FTP_USERNAME,$FTP_PASSWORD -e "$FTP_COMMANDS" $FTP_SERVER

ftp -n $FTP_SERVER << END_SCRIPT
#quote $FTP_USERNAME
#quote $FTP_PASSWORD
source "$FTP_COMMANDS"
#END_SCRIPT

# Clean up FTP commands file
#rm -f "$FTP_COMMANDS"
#
