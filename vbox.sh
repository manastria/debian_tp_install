# Set VirtualBox Variable so argument from command line gets passed through
VBOX_VERSION=$1

# Install prereqs
apt install -y dkms

# Change to temp directory and download VboxGuestAdditions
cd /tmp
curl -O http://download.virtualbox.org/virtualbox/$VBOX_VERSION/VBoxGuestAdditions_$VBOX_VERSION.iso

# Mount and run iso
# mount /dev/cdrom /mnt/
mount -o loop,ro VBoxGuestAdditions_$VBOX_VERSION.iso /mnt
sh /mnt/VBoxLinuxAdditions.run

# Cleanup
umount /mnt
rm /tmp/VBoxGuestAdditions_$VBOX_VERSION.iso
