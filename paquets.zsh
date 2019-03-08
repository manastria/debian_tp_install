#!/usr/bin/zsh

bases=(
    aptitude
    bash-completion
    build-essential
    byobu
    ccze
    curl
    git
    gpgv2
    haveged
    less
    linux-headers-$(uname -r)
    lnav
    locales-all
	mlocate
    most
    multitail
    rng-tools
    screen
    screenfetch
    sudo
    tmux
	tree
    unzip
    vim
    yadm
    zip
    zsh
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


tpgnome=(
    gnome-core
    open-vm-tools-desktop
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

apache=(
    apache2
    php7.0
    libapache2-mod-php7.0
    php7.0-intl
    php7.0-mcrypt
    php7.0-ldap
    php7.0-gd
    php7.0-imagick
    php7.0-pdo-sqlite
    php7.0-sqlite3

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

basenet=(
	net-tools
)

tp=(
	apt-file
	command-not-found
	sudo
	etckeeper
)

lamp=(
	$apache
	$bind
	$mysql
	php7.0-mysqli
)

gpg=(
	gpgv2
	signing-party
	debian-keyring
	cryptsetup-bin
	qrencode
	dirmngr
)

gpg_gui=(
	$gpg
	seahorse
	keepass2
    kgpg
)

gui_base=(
	firefox-esr
	firefox-esr-gnome-keyring
    konsole
    terminator
)

for INSTPKT
do
    case ${INSTPKT} in
	bases)
        echo "Installation des paquets de bases"
		paquets=($paquets $bases)
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
    apache)
        echo "Installation d'Apache"
		paquets=($paquets $apache)
        ;;
    gnome)
        echo "Installation de Gnome"
		paquets=($paquets $gnome)
        ;;
    tpgnome)
        echo "Installation de TP Gnome"
		paquets=($paquets $tpgnome)
        ;;
    tp)
        echo "Installation de tp"
		paquets=($paquets $tp)
        ;;
    basenet)
        echo "Installation de basenet"
		paquets=($paquets $basenet)
        ;;
    lamp)
        echo "Installation de lamp"
		paquets=($paquets $lamp)
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

