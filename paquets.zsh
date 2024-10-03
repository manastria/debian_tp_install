#!/usr/bin/zsh

# netcat + telnet pour TP Postfix


bases=(
    aptitude
    acl
    bash-completion
    bat
    build-essential
    byobu
    ccze
    curl
    git
    gnupg2
    haveged
    less
    linux-headers-$(uname -r)
    lnav
    locales-all
    mlocate
    most
    multitail
    parted
    reptyr
    rng-tools
    screen
    screenfetch
	neofetch
    sudo
    tmux
    tree
    unzip
    vim
    yadm
    zip
    zsh
)

base_debian=(
    netselect-apt
)


bind=(
	bind9
	bind9-host
	dnsutils
)

gnome=(
    gnome-core
#	libgl1-mesa-dri
#	open-vm-tools-desktop
#	xserver-xorg-video-vmware
)


gnome_tp=(
    gnome-core
    open-vm-tools-desktop
    x11-apps
    xfonts-100dpi
    xfonts-75dpi
)

vmware_cli=(
    open-vm-tools
)

vmware_gui=(
    open-vm-tools-desktop
)

lxc=(
    lxc
    bridge-utils
    vlan
    libvirt-daemon-system
    libvirt-dev
    libvirt-clients
    debootstrap
    vde2
    openvswitch-switch
    xfce4
    galculator
    open-vm-tools-desktop
    terminator
    wireshark
    traceroute
    nmap
    zenmap
    netcat
    ipcalc
    gip
    etckeeper
    glances
    net-tools
)

other=(
    iputils-ping
    apt-file
    command-not-found
    perl
    libnet-ssleay-perl
    openssl
    libauthen-pam-perl
    libpam-runtime
    libio-pty-perl
    apt-show-versions
    python
)

phpmyadmin=(
	$lamp
	phpmyadmin
	php-mbstring
	php-gettext
)

apache=(
    apache2
    php
    libapache2-mod-php
    php-intl
    php-ldap
    php-gd
    php-imagick
    php7.3-sqlite3
    php-sqlite3

    openssl
)

mysql=(
	mysql-client
	mysql-server
)

postfixadmin=(
	postfixadmin
)

postfix=(
	postfix
	postfix-mysql
	postfix-pcre
	sasl2-bin
	libsasl2-modules
	libsasl2-modules-sql
	mailutils
)

dovecot=(
	dovecot-mysql
	dovecot-pop3d
	dovecot-imapd
	dovecot-managesieved
)

roundcube=(
	roundcube
	roundcube-mysql
	roundcube-plugins
	roundcube-plugins-extra
)

basenet=(
	net-tools
	tcpdump
)

tp=(
	apt-file
    bpytop
	command-not-found
#   chkservice
    fasd
    fzf
	sudo
	etckeeper
    lsd
	sl
	glances
	tty-clock
	htop
	dfc
    snapd
	tftp-hpa
	avahi-daemon
	libnss-mdns
)

lamp=(
	$apache
	$bind
	$mysql
	php-mysqli
)

gpg=(
	gnupg2
	dirmngr
	signing-party
	debian-keyring
	cryptsetup-bin
	qrencode
	dirmngr
	ghostscript
	python3-gpg
)

gpg_gui=(
	$gpg
	seahorse
	keepass2
    kgpg
)

gui_base=(
	firefox-esr
    konsole
    terminator
)

gui_mail=(
	evolution
)

mint=(
	yakuake
	guake
	terminator
	konsole
)

for INSTPKT
do
    case ${INSTPKT} in
	bases)
        echo "Installation des paquets de bases"
		paquets=($paquets $bases)
        ;;
	base_debian)
        echo "Installation des paquets de bases"
		paquets=($paquets $bases $base_debian)
        ;;
	bind)
        echo "Installation des paquets de bases"
		paquets=($paquets $bind)
        ;;
	postfix)
        echo "Installation de postfix"
		paquets=($paquets $postfix)
        ;;
	postfixadmin)
        echo "Installation de postfixadmin"
		paquets=($paquets $postfixadmin)
        ;;
	phpmyadmin)
        echo "Installation de phpmyadmin"
		paquets=($paquets $phpmyadmin)
        ;;
    apache)
        echo "Installation d'Apache"
		paquets=($paquets $apache)
        ;;
    gnome)
        echo "Installation de Gnome"
		paquets=($paquets $gnome)
        ;;
    gnome_tp)
        echo "Installation de TP Gnome"
		paquets=($paquets $gnome_tp)
        ;;
    tp)
        echo "Installation de tp"
		paquets=($paquets $bases $tp)
        ;;
    basenet)
        echo "Installation de basenet"
		paquets=($paquets $basenet)
        ;;
    lamp)
        echo "Installation de lamp"
		paquets=($paquets $lamp)
        ;;
    mint)
        echo "Installation de mint"
		paquets=($paquets $mint $gpg_gui)
        ;;
	mysql)
        echo "Installation de mysql"
		paquets=($paquets $mysql)
        ;;
    gnomevm)
        echo "Installation de gnomevm"
		paquets=($paquets $gnome $vmware_gui)
		;;
	gpg)
        echo "Installation de gpg"
		paquets=($paquets $gpg)
        ;;
	gpg_gui)
        echo "Installation de gpg_gui"
		paquets=($paquets $gpg_gui)
		;;
	gui_base)
        echo "Installation de gui_base"
		paquets=($paquets $gui_base)
		;;
	dovecot)
        echo "Installation de dovecot"
		paquets=($paquets $dovecot)
		;;
	postfixadmin)
        echo "Installation de postfixadmin"
		paquets=($paquets $postfixadmin)
		;;
	gui_mail)
        echo "Installation de gui_mail"
		paquets=($paquets $gui_mail)
		;;
	roundcube)
	    echo "Installation de roundcube"
		paquets=($paquets $roundcube)
		;;
	vmware_cli)
		echo "Installation des VM Tools pour CLI"
		paquets=($paquets $vmware_cli)
		;;
	vmware_gui)
		echo "Installation des VM Tools pour Desktop"
		paquets=($paquets $vmware_gui)
		;;
	*)
		echo "Incorrect : ${INSTPKT}" >&2
		exit 1
		;;
    esac
done

typeset -U paquets

setopt shwordsplit
# Print sorted list
paquets=$(echo $(echo -e "${paquets// /\\n}" | sort -u))
echo ${paquets}

#apt update
## apt install -y --no-install-recommends --no-install-suggests $paquets
apt install -y $paquets
