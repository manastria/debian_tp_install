# Installation d'une VM Debian 11


### Initialisation


```
apt install pipenv python3-yaml
```

### Modifier les dépôts pour pousser
```
git remote set-url --push origin git@bitbucket.org:manastria/debian_tp_install.git
```

```
yadm remote set-url --push origin git@bitbucket.org:manastria/dotfile.git
```


### yadm

Ne pas s'occuper d'yadm : c'est le script baseV10.zsh

```
# yadm clone https://manastria@bitbucket.org/manastria/dotfile.git
# yadm clone git@bitbucket.org:manastria/dotfile.git
# yadm remote set-url origin https://manastria@bitbucket.org/manastria/dotfile.git
```

```
# yadm reset --hard origin/master
```


### baseV12

```
apt.sh
./bin/install_packages.py -c debian_11
```

Installation et configuration de yadm


=== Installation du dépôt Git

----
git clone https://bitbucket.org/manastria/debian_tp_install.git
----


Quelques commandes utiles :
----
# git clone https://manastria@bitbucket.org/manastria/debian_tp_install.git
# git clone git@bitbucket.org:manastria/debian_tp_install.git
# git remote set-url origin https://manastria@bitbucket.org/manastria/dotfile.git
----

=== Lancer le script init.sh




## Ne pas s'occuper d'yadm : c'est le script baseV10.zsh

# yadm clone https://manastria@bitbucket.org/manastria/dotfile.git
# yadm clone git@bitbucket.org:manastria/dotfile.git
# yadm remote set-url origin https://manastria@bitbucket.org/manastria/dotfile.git

# yadm reset --hard origin/master






===================== Debut

# cat > /etc/apt/apt.conf.d/01proxy << EOF
Acquire::http::Proxy "http://192.168.1.81:9999";
EOF

Le proxy est peut-être déjà configuré dans `# cat /etc/apt/apt.conf`

mkdir -p ~/.ssh
touch ~/.ssh/authorized_keys
echo "ssh-rsa AAAAB3NzaC1yc2EAAAABJQAAAQEAguQl+vaaMp1KNGPIjnf64D/hhfV2XbcvnpUghSjen0Xr63G05shYYasLngdXbI9Hxr9BE456Qw1+Y78VUks88ZWat+wENCVvZpLHwyjTFk7yupExYpctZBgoPZyaTiTIILjVLAhIDKk6/gAXviRF6UwRKtltZJE0k0fiFnLwSFPw7b0MpjZnS8sUKQR4ZvK87yJhx+p5LVQRwRwVILBRWVAkdHLqtxACzoykac1GbtUFgpqkMzhF6kUfb75ozYkHoLSH7CLs5ac13SYml3Hl5DoIKsBQfoDlOoI7V1WKgH8G4yd9lYobEbc2hGZDkdcqSA2jvSNeKHpo1fEKpja/Cw== TP03" >> ~/.ssh/authorized_keys
ln -s ~/.ssh/authorized_keys ~/.ssh/authorized_keys2
chmod -R 700 ~/.ssh
chmod 0600 ~/.ssh/authorized_keys*


zsh baseV10.zsh
./install_rngtools.sh
./install_tp.sh
./install_issue.sh
./paquets.zsh apache
./install_webmin.zsh
./paquets.zsh gpg vmware_cli
# tar -x -C / -f ndg_unhatched.tar.bz2
chown -R sysadmin:sysadmin /home/sysadmin


## Gnome
./paquets.zsh gnome vmware_gui gpg_gui gui_base

/!\ Commenter les lignes correspondant à l'interface ens33 dans /etc/network/interfaces
Tester si `rm /etc/xdg/autostart/org.kde.kgpg.desktop` résoud le problème.

/!\ Lancer make_rclocal.sh

####### Passwd : Pass!MySQL_456



Retirer le proxy dans /etc/apt/apt.conf


Retailler la partion
lvresize --resizefs -l +100%FREE /dev/linux1-vg/root



==================== Modifier le timeout de Grub

----
cat /etc/default/grub
# If you change this file, run 'update-grub' afterwards to update
# /boot/grub/grub.cfg.
# For full documentation of the options in this file, see:
#   info -f grub -n 'Simple configuration'

GRUB_DEFAULT=0
GRUB_TIMEOUT=2
GRUB_DISTRIBUTOR=`lsb_release -i -s 2> /dev/null || echo Debian`
GRUB_CMDLINE_LINUX_DEFAULT="quiet"
GRUB_CMDLINE_LINUX=""
----

# update-grub


==================== Supprimer les noms des interfaces

vi /etc/default/grub

Look for GRUB_CMDLINE_LINUX line and add net.ifnames=0 biosdevname=0.

FROM:

GRUB_CMDLINE_LINUX=""

TO:

GRUB_CMDLINE_LINUX="net.ifnames=0 biosdevname=0"

Generate a new grub configuration file using the grub-mkconfig command.

sudo grub-mkconfig -o /boot/grub/grub.cfg







==================== vivid
----
dpkg -i vivid*
----





====================== CLEAN

rm -rf ~/.local/* ~/.cache/* ~/.thumbs/*


==================== POST INSTALLATION ===================

Avec l'utilisateur sysadmin pour permettre à l'utilisateur root d'exécuter des applis graphique

----
xhost +si:localuser:Root
----


Vider le fichier interfaces




== Installation
== Initialisation de la VM

=== Donner un accès à l'utilisateur root en SSH

----
# apt update && apt install -y openssh-server
# vi /etc/ssh/sshd_config
/Root
yyp0xwDAyes
# systemctl restart sshd
----




















=== Installation des paquets de base
----
# apt update && apt upgrade -y && apt install -y git zsh vim yadm aptitude pip && reboot
----

> Il faudrait faire un snapshot.

Se connecter en SSH

# git clone https://bitbucket.org/manastria/debian_tp_install.git
# cd debian_tp_install
# git checkout --track origin/debian-11

## Installation de la distribution

```
# ./tp_cli.sh
```
/!\ Installer Network Manager tout de suite avant de rebooter, sinon, il faudra configurer le réseau manuellement ! Mais on peut lancer la configuration en DHCP avec la commande `dhclient eth0`.
```
./install_network-manager.sh
```

# Installation des paquets
git clone https://github.com/manastria/debian_install_python.git

pip install PyYAML

```
# ./install_packages.py -c debian_11 -s base
```


=== Installation du dépôt Git

----
git clone https://bitbucket.org/manastria/debian_tp_install.git
----



=== 


  * apt full-upgrade
  * `git pull` dans debian_tp_install
  * ./tp_cli.sh
  * reboot
  * ./tp_gui.sh
  * commenter les lignes `ens33` dans le fichier `/etc/network/interfaces`
  * `xhost +si:localuser:root`
  * Mettre le lien pour la console
  * Retirer le proxy ?????
  * ./clean_system.sh




















Pour yadm seulement
====================



sudo apt install -y git zsh vim yadm bash-completion byobu ccze curl lnav mlocate most multitail reptyr screen screenfetch sudo tmux tree unzip zip haveged


yadm clone https://manastria@bitbucket.org/manastria/dotfile.git

yadm reset --hard origin/master








### Modifier les dépôts pour pousser
```
git remote set-url --push origin git@bitbucket.org:manastria/debian_tp_install.git
```

```
yadm remote set-url --push origin git@bitbucket.org:manastria/dotfile.git
```
