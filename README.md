# apt update && apt install -y openssh-server
# vi /etc/ssh/sshd_config
/Root
yyp0xwDAyes
# systemctl restart sshd




# apt update && apt install -y git zsh vim yadm


# git clone https://github.com/manastria/debian_tp_install.git
# git clone git@github.com:manastria/debian_tp_install.git

# yadm clone https://manastria@bitbucket.org/manastria/dotfile.git
# yadm clone git@bitbucket.org:manastria/dotfile.git
# yadm reset --hard origin/master

mkdir -p ~/.ssh
touch ~/.ssh/authorized_keys
echo "ssh-rsa AAAAB3NzaC1yc2EAAAABJQAAAQEAguQl+vaaMp1KNGPIjnf64D/hhfV2XbcvnpUghSjen0Xr63G05shYYasLngdXbI9Hxr9BE456Qw1+Y78VUks88ZWat+wENCVvZpLHwyjTFk7yupExYpctZBgoPZyaTiTIILjVLAhIDKk6/gAXviRF6UwRKtltZJE0k0fiFnLwSFPw7b0MpjZnS8sUKQR4ZvK87yJhx+p5LVQRwRwVILBRWVAkdHLqtxACzoykac1GbtUFgpqkMzhF6kUfb75ozYkHoLSH7CLs5ac13SYml3Hl5DoIKsBQfoDlOoI7V1WKgH8G4yd9lYobEbc2hGZDkdcqSA2jvSNeKHpo1fEKpja/Cw== TP03" >> ~/.ssh/authorized_keys
ln -s ~/.ssh/authorized_keys ~/.ssh/authorized_keys2
chmod -R 700 ~/.ssh
chmod 0600 ~/.ssh/authorized_keys*




===================== Debut

# cat > /etc/apt/apt.conf.d/01proxy << EOF
Acquire::http::Proxy "http://192.168.1.81:9999";
EOF


# apt update && apt install -y git zsh vim yadm etckeeper && etckeeper commit -m "Installation de Debian"
# git clone git@github.com:manastria/debian_tp_install.git


./base.zsh
./install_tp.sh
./install_rngtools.sh
./install_issue.sh
./paquets.zsh apache
./install_webmin.zsh
./install_mysql.zsh
####### Passwd : Pass!MySQL_456

