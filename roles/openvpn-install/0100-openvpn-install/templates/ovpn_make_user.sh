#!/bin/bash
set -e
if [ -z $1 ]; then
  echo "Need username as first parameter!"
  exit 1
fi

export USER_NAME=$1

# Ensure user archive directory exists
if [ ! -d {{ openvpn_archive_path }}/${USER_NAME} ]; then 
    mkdir -p {{ openvpn_archive_path }}/${USER_NAME}
fi

# Check the request file already exist
if [ -f {{ openvpn_root_path }}/server/pki/reqs/${USER_NAME}.req ]; then 
    echo "Request file '{{ openvpn_root_path }}/server/pki/reqs/${USER_NAME}.req'  already exists."
    exit 0
else
    cd {{ openvpn_root_path }}/server
    ./easyrsa build-client-full $USER_NAME nopass
fi

export CA_FILE_PATH={{ openvpn_root_path }}/server/pki/ca.crt
export USER_CERT_FILE_PATH={{ openvpn_root_path }}/server/pki/issued/${USER_NAME}.crt
export USER_KEY_FILE_PATH={{ openvpn_root_path }}/server/pki/private/${USER_NAME}.key

declare -a Files=(
    $CA_FILE_PATH
    $USER_CERT_FILE_PATH
    $USER_KEY_FILE_PATH
  );

  # check existing every files
  for i in "${Files[@]}"
  do
    if [[ ! -f $i ]]; then
      echo 'file' $i 'do not exist'
      exit 1
    fi
  done

# save data in files to variables
export CA_FILE="$(<$CA_FILE_PATH)"
export USER_CERT_FILE="$(<$USER_CERT_FILE_PATH)"
export USER_KEY_FILE="$(<$USER_KEY_FILE_PATH)"

# Fill out conffile with above values
if [ -f {{ openvpn_root_path }}/client.template.conf ]; then
        envsubst < {{ openvpn_root_path }}/client.template.conf > {{ openvpn_archive_path }}/${USER_NAME}/{{ openvpn_server_name }}.ovpn
fi

# Make 2FA code
wget `google-authenticator --time-based --disallow-reuse --force --rate-limit=3 --rate-time=30 --window-size=3 -l 'OpenVPN' -s {{ openvpn_root_path }}/server/otp/${USER_NAME}.google_authenticator | grep https | head -n1` -O {{ openvpn_archive_path }}/${USER_NAME}/2FA_QR_CODE.png
head -n1 {{ openvpn_root_path }}/server/otp/${USER_NAME}.google_authenticator > {{ openvpn_archive_path }}/${USER_NAME}/2FA_RECOVERY_CODE.txt