

VBOX_LATEST_VERSION=$(curl -s http://download.virtualbox.org/virtualbox/LATEST.TXT)

VBOX_LATEST_FILE_WIN=$(wget -q http://download.virtualbox.org/virtualbox/${VBOX_LATEST_VERSION}/MD5SUMS -O- | grep -i "OSX.dmg" | cut -d"*" -f2)

mkdir -p ${TEMP}/vbox
cd ${TEMP}/vbox

wget -c https://download.virtualbox.org/virtualbox/${VBOX_LATEST_VERSION}/SHA256SUMS
VBOX_LATEST_FILE_WIN=$(grep -i "Win.exe" SHA256SUMS | cut -d"*" -f2)
wget -c https://download.virtualbox.org/virtualbox/${VBOX_LATEST_VERSION}/${VBOX_LATEST_FILE_WIN}
wget -c https://download.virtualbox.org/virtualbox/${VBOX_LATEST_VERSION}/UserManual.pdf
wget -c https://download.virtualbox.org/virtualbox/${VBOX_LATEST_VERSION}/VBoxGuestAdditions_${VBOX_LATEST_VERSION}.iso
wget -c https://download.virtualbox.org/virtualbox/${VBOX_LATEST_VERSION}/Oracle_VM_VirtualBox_Extension_Pack-${VBOX_LATEST_VERSION}.vbox-extpack

sha256sum -c SHA256SUMS 2>&1 | grep OK
