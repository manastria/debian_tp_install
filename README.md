# apt update && apt install -y openssh-server
# vi /etc/ssh/sshd_config
/Root
yyp0xwDAyes
# systemctl restart sshd


# cat > /etc/apt/apt.conf.d/01proxy << EOF
Acquire::http::Proxy "http://192.168.1.81:9999";
EOF

# apt update && apt install -y git zsh vim yadm


# git clone https://github.com/manastria/debian_tp_install.git
# git clone git@github.com:manastria/debian_tp_install.git

# yadm clone https://manastria@bitbucket.org/manastria/dotfile.git
# yadm clone git@bitbucket.org:manastria/dotfile.git
# yadm reset --hard origin/master



apt update && apt install -y git zsh vim yadm
git clone git@github.com:manastria/debian_tp_install.git
./base.zsh
./install_tp.sh
./install_rngtools.sh
./install_issue.sh
./paquets.zsh -p apache
./install_webmin.zsh
./install_mysql.zsh
####### Passwd : netlab123

