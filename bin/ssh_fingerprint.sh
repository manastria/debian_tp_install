#!/usr/bin/bash

NB_COL=$(tput cols)

for FILE in /etc/ssh/*.pub; do
  echo
  printf -- '=%.0s' {1..100} ; echo
  echo $FILE;
  printf -- '=%.0s' {1..100} ; echo
  cat $FILE;
  printf -- '-%.0s' {1..100} ; echo

  echo "  MD5-hex : " $(ssh-keygen -l -f "${FILE}" -E md5)
  echo "  SHA1-base64 : " $(ssh-keygen -l -f "${FILE}" -E sha1)
  echo "  SHA256-base64 : " $(ssh-keygen -l -f "${FILE}" -E sha256)

  echo "  MD5-hex : " $(awk '{print $2}' "${FILE}" | base64 -d | md5sum)
  echo "  SHA1-hex : " $(awk '{print $2}' "${FILE}" | base64 -d | sha1sum)
  echo "  SHA256-hex : " $(awk '{print $2}' "${FILE}" | base64 -d | sha256sum)

  echo "  MD5-base64 : " $(awk '{print $2}' "${FILE}" | base64 -d | md5sum | xxd -r -p | base64)
  echo "  SHA1-base64 : " $(awk '{print $2}' "${FILE}" | base64 -d | sha1sum | xxd -r -p | base64)
  echo "  SHA256-base64 : " $(awk '{print $2}' "${FILE}" | base64 -d | sha256sum | xxd -r -p | base64)

  ssh-keygen -lvf "${FILE}" -E md5 | sed 's/^/  /'
  ssh-keygen -lvf "${FILE}" -E sha1 | sed 's/^/  /'
  ssh-keygen -lvf "${FILE}" -E sha256 | sed 's/^/  /'

done;
echo
