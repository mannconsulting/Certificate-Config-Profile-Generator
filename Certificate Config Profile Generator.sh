#!/bin/zsh
###############################################################################
# Certificate Config Profile Generator
# Created by:    Mann Consulting (support@mann.com)
# Summary:       Script to convert a PEM file with multiple certificates into a Configuration Profile
#                that contains all the certificates.
#
# Documentation: https://mann.com/docs
#
# Note:	         This script released publicly, but intended for Mann Consulting's Jamf Pro MSP customers.
#                If you'd like support sign up at https://mann.com/jamf or email support@mann.com for more details
###############################################################################collectionFile=$1
collectionFile=$1
tmp=$(mktemp -d)
if [[ -z "$collectionFile" ]]; then
  echo "no file found"
fi
certname=$(basename $collectionFile)

grep -v -E 'issuer|subject' "$collectionFile" | split -p "-----BEGIN CERTIFICATE-----" - "$tmp"/certificate-

for i in `ls "$tmp"/certificate-*`; do
  certnumber=$((certnumber+1))
  loopuuid=$(uuidgen)
  subject=$(openssl x509 -subject -issuer -noout -in $i | grep subject | cut -d '=' -f2-)
  issuer=$(openssl x509 -subject -issuer -noout -in $i | grep issuer | cut -d '=' -f2-)
  if [[ $subject == $issuer ]];then
    payloadtype="com.apple.security.root"
  else
    payloadtype="com.apple.security.pkcs1"
  fi
  certdata+="
                  <dict>
                        <key>PayloadUUID</key>
                        <string>$loopuuid</string>
                        <key>PayloadType</key>
                        <string>$payloadtype</string>
                        <key>PayloadOrganization</key>
                        <string>Mann Consulting</string>
                        <key>PayloadIdentifier</key>
                        <string>$loopuuid</string>
                        <key>PayloadDisplayName</key>
                        <string>$certname-$certnumber</string>
                        <key>PayloadDescription</key>
                        <string/>
                        <key>PayloadVersion</key>
                        <integer>1</integer>
                        <key>PayloadEnabled</key>
                        <true/>
                        <key>PayloadCertificateFileName</key>
                        <string>$certname-$certnumber.cer</string>
                        <key>PayloadContent</key>
                        <data>$(grep -v 'CERTIFICATE' $i | tr -d '\n')</data>
                        <key>AllowAllAppsAccess</key>
                        <true/>
                        <key>KeyIsExtractable</key>
                        <true/>
                  </dict>"
done

uuid1=$(uuidgen)
uuid2=$(uuidgen)
profile="<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version=\"1\">
      <dict>
            <key>PayloadUUID</key>
            <string>$uuid1</string>
            <key>PayloadType</key>
            <string>Configuration</string>
            <key>PayloadOrganization</key>
            <string>Mann Consulting</string>
            <key>PayloadIdentifier</key>
            <string>$uuid1</string>
            <key>PayloadDisplayName</key>
            <string>$certname Certificates</string>
            <key>PayloadDescription</key>
            <string>Created on $(date) using Mann Consulting's Certificate Config Profile Generator.  More Info: https://mann.com/docs</string>
            <key>PayloadVersion</key>
            <integer>1</integer>
            <key>PayloadEnabled</key>
            <true/>
            <key>PayloadRemovalDisallowed</key>
            <true/>
            <key>PayloadScope</key>
            <string>System</string>
            <key>PayloadContent</key>
            <array>$certdata
            </array>
      </dict>
</plist>"
echo $profile > "$collectionFile".mobileconfig
open $(dirname $collectionFile)
rm -Rf "$tmp"