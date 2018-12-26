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

paquets=(
    $bases
)
typeset -U paquets


while getopts ':sp:' arg; do
    case $arg in
    s) print got s; s=sss;;
    p)
        echo "-p $OPTARG" >&2
        INSTPKT=$OPTARG
        ;;
    \*) 
        print nothing: $OPTARG;;
    \?)
        echo "Invalid option: -$OPTARG" >&2
        exit 1
        ;;
    :)
        echo "Option -$OPTARG requires an argument." >&2
        exit 1
        ;;
    esac
done

if [ ! -z ${INSTPKT} ]
then
    case ${INSTPKT} in
    apache)
        echo "Installation d'Apache"
        paquets+=${apache}
        ;;
    gnome)
        echo "Installation de Gnome"
        paquets+=${apache}
        ;;
    esac
fi

typeset -U paquets

# Print sorted list
echo $(echo -e "${paquets// /\\n}" | sort -u)

#apt update
## apt install -y --no-install-recommends --no-install-suggests $paquets
apt install -y $paquets

