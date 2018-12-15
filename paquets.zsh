#/usr/bin/zsh

cat > /etc/apt/sources.list <<EOF
#deb cdrom:[Debian GNU/Linux 9.5.0 _Stretch_ - Official amd64 NETINST 20180714-10:25]/ stretch main

deb http://debian.mirrors.ovh.net/debian/ stretch main contrib non-free
deb-src http://debian.mirrors.ovh.net/debian/ stretch main contrib non-free

deb http://security.debian.org/debian-security stretch/updates main contrib non-free
deb-src http://security.debian.org/debian-security stretch/updates main contrib non-free

# stretch-updates, previously known as 'volatile'
deb http://debian.mirrors.ovh.net/debian/ stretch-updates main contrib non-free
deb-src http://debian.mirrors.ovh.net/debian/ stretch-updates main contrib non-free
EOF



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
gdm3                       # The display manager
gnome-session
gnome-shell
gnome-keyring
libpam-gnome-keyring
gnome-control-center
network-manager-gnome
gnome-terminal
)

vmware=(
    open-vm-tools-desktop
    open-vm-tools
)

paquets=(
$bases
)

typeset -U paquets

apt update
apt install -y --no-install-recommends --no-install-suggests $paquets

