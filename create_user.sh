#!/usr/bin/env bash


if [[ $# -eq 0 ]] ; then
    echo 'No arguments supplied'
    exit 1
fi

USERNAME=$1

if ! id -u ${USERNAME} > /dev/null 2>&1
then
    pass=$(perl -e 'print crypt($ARGV[0], "password")' 'netlab123')
    useradd -m -s /bin/bash -p $pass ${USERNAME}
fi

sudo -u ${USERNAME} --set-home yadm clone https://manastria@bitbucket.org/manastria/dotfile.git
sudo -u ${USERNAME} --set-home yadm reset --hard origin/master

## Configure la clé SSH
HOME_PATH=/home/${USERNAME}
mkdir -p ${HOME_PATH}/.ssh
touch ${HOME_PATH}/.ssh/authorized_keys
echo "ssh-rsa AAAAB3NzaC1yc2EAAAABJQAAAQEAguQl+vaaMp1KNGPIjnf64D/hhfV2XbcvnpUghSjen0Xr63G05shYYasLngdXbI9Hxr9BE456Qw1+Y78VUks88ZWat+wENCVvZpLHwyjTFk7yupExYpctZBgoPZyaTiTIILjVLAhIDKk6/gAXviRF6UwRKtltZJE0k0fiFnLwSFPw7b0MpjZnS8sUKQR4ZvK87yJhx+p5LVQRwRwVILBRWVAkdHLqtxACzoykac1GbtUFgpqkMzhF6kUfb75ozYkHoLSH7CLs5ac13SYml3Hl5DoIKsBQfoDlOoI7V1WKgH8G4yd9lYobEbc2hGZDkdcqSA2jvSNeKHpo1fEKpja/Cw== TP03b" >>${HOME_PATH}/.ssh/authorized_keys
echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDc+e2L7GFcoWgE2qhVpQmBq2jiCZtXj1vIpFG/+N7Yw TP04" >>${HOME_PATH}/.ssh/authorized_keys
if [ -L ${HOME_PATH}/.ssh/authorized_keys -a -f ${HOME_PATH}/.ssh/authorized_keys2 ]; then rm ${HOME_PATH}/.ssh/authorized_keys && mv ${HOME_PATH}/.ssh/authorized_keys2 ${HOME_PATH}/.ssh/authorized_keys; fi
if [ ! -e ${HOME_PATH}/.ssh/authorized_keys2 ]; then ln -s ${HOME_PATH}/.ssh/authorized_keys ${HOME_PATH}/.ssh/authorized_keys2; fi

rm -rf /tmp/known_hosts
ssh-keyscan -H github.com >>/tmp/known_hosts
ssh-keyscan -H bitbucket.org >>/tmp/known_hosts
cat /tmp/known_hosts >>${HOME_PATH}/.ssh/known_hosts


sort -u -o ${HOME_PATH}/.ssh/known_hosts ${HOME_PATH}/.ssh/known_hosts
sort -u -o ${HOME_PATH}/.ssh/authorized_keys ${HOME_PATH}/.ssh/authorized_keys

chown -R ${USERNAME} ${HOME_PATH}/.ssh


find ${HOME_PATH}/.ssh/ -type f -exec chmod 600 {} \;
find ${HOME_PATH}/.ssh/ -type d -exec chmod 700 {} \;
find ${HOME_PATH}/.ssh/ -type f -name "*.pub" -exec chmod 644 {} \;


