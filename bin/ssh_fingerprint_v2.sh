#!/bin/sh

FILE=/etc/ssh/ssh_host_rsa_key.pub

echo ${FILE}
#echo "ssh-keygen"

#echo "MD5-hex : "
#ssh-keygen -l -f "${FILE}" -E md5

#echo "SHA1-base64 : "
#ssh-keygen -l -f "${FILE}" -E sha1
#echo "SHA256-base64 : "
#ssh-keygen -l -f "${FILE}" -E sha256

echo ""
echo "Format hex"
#echo "MD5-hex : "
#awk '{print $2}' "${FILE}" | base64 -d | md5sum
echo "MD5-base64 : "
awk '{print $2}' "${FILE}" | base64 -d | md5sum | xxd -r -p | base64
echo "SHA1-hex : "
awk '{print $2}' "${FILE}" | base64 -d | sha1sum
echo "SHA256-hex : "
awk '{print $2}' "${FILE}" | base64 -d | sha256sum
#echo "SHA1-base64 : "
#awk '{print $2}' "${FILE}" | base64 -d | sha1sum | xxd -r -p | base64
#echo "SHA256-base64 : "
#awk '{print $2}' "${FILE}" | base64 -d | sha256sum | xxd -r -p | base64

echo ""
ssh-keygen -lvf "${FILE}" -E md5
ssh-keygen -lvf "${FILE}" -E sha1
ssh-keygen -lvf "${FILE}" -E sha256

