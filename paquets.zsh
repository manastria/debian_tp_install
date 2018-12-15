#/usr/bin/zsh


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



paquets=(
$bases
$gnome
)

typeset -U paquets

apt update
apt install --no-install-recommends $paquets

