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
    most
    multitail
    rng-tools
    screen
    screenfetch
    sudo
    tmux
    unzip
    vim
    yadm
    zip
    zsh
)

gnome=(
    gnome-core
)

vmware=(
    open-vm-tools-desktop
    open-vm-tools
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
    php7.0-mysql
    openssl
)

postfix=(
	postfixadmin
	postfix
	postfix-mysql
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


for INSTPKT
do
    case ${INSTPKT} in
	bases)
        echo "Installation des paquets de bases"
		paquets=($paquets $bases)
        ;;
	postfix)
        echo "Installation de postfix"
		paquets=($paquets $postfix)
        ;;
    apache)
        echo "Installation d'Apache"
		paquets=($paquets $apache)
        ;;
    gnome)
        echo "Installation de Gnome"
		paquets=($paquets $gnome)
        ;;
    tp)
        echo "Installation de tp"
		paquets=($paquets $tp)
        ;;
    basenet)
        echo "Installation de basenet"
		paquets=($paquets $basenet)
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

