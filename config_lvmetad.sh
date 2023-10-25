#!/bin/bash

## Warning lors du démarrage : "Failed to connect to lvmetad"


# sed -rn -e '/^[[:blank:]]+use_lvmetad =/ s/=.*/= 0/gp' /etc/lvm/lvm.conf

# Modifier la valeur use_lvmetad = 0
sed -ri -e '/^[[:blank:]]+use_lvmetad =/ s/=.*/= 0/' /etc/lvm/lvm.conf

# Maj du système
update-initramfs -k $(uname -r) -u; sync
