#/bin/bash

echo -e "\033[34m===============================================================================\033[0m"
echo "Reconfigure openssh-server"
echo -e "\033[34m===============================================================================\033[0m"
echo 'openssh-server openssh-server/permit-root-login boolean true' | debconf-set-selections
sed -i '/^#\?[[:space:]]*permitrootlogin/Ic\PermitRootLogin yes' /etc/ssh/sshd_config

systemctl restart ssh.service
