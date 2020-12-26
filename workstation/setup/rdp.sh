
#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e

DUC_VERSION="v3.9.1"
XRDP_VERSION="v0.9.13"
SETUP_CHECK="$KIRA_SETUP/rdp-v1-$DUC_VERSION"
SUCCESS="true"
if [ ! -f "$SETUP_CHECK" ] ; then
    echo "INFO: Setting up remote desktop protocol..."
    
    echo "INFO: Installing DUC dependencies..."
    apt-get update -y
    apt-get install -y perl libdata-validate-ip-perl libio-socket-ssl-perl libjson-perl
    echo "INFO: Installing XRDP dependencies..."
    apt-get install -y autoconf libtool fuse libpam0g-dev libjpeg-dev libfuse-dev libx11-dev libxfixes-dev \
        libxrandr-dev nasm gnome-tweak-tool net-tools

    # Info: https://github.com/ddclient/ddclient
    echo "INFO: Setting up DUC..."
    
    DDC_DIR="/home/$SUDO_USER/ddc"
    $KIRA_SCRIPTS/git-pull.sh "https://github.com/ddclient/ddclient.git" "$DUC_VERSION" "$DDC_DIR" || SUCCESS="false"
    FILE_HASH=$(CDHelper hash SHA256 -p="$DDC_DIR" -x=true -r=true --silent=true -i="$DDC_DIR/.git,$DDC_DIR/.gitignore")
    EXPECTED_HASH="90cd72158c37309d2f265117f2bd418464c488ee95f7874b0bd5bdfebce2cb70"
    [ "${SUCCESS,,}" != "true" ] && echo "INFO: Failed to download DUC" && exit 0
    [ "${FILE_HASH}" != "${EXPECTED_HASH}" ] && echo "INFO: Faile do verify inegrity of the DUC repository" && exit 0
    cd $DDC_DIR

    cp -fv ddclient /usr/sbin/
    mkdir -p /etc/ddclient
    mkdir -p /var/cache/ddclient
    [ ! -f "/etc/ddclient/ddclient.conf" ] && cp -fv sample-etc_ddclient.conf /etc/ddclient/ddclient.conf

    cp -fv sample-etc_systemd.service /etc/systemd/system/ddclient.service
    systemctl daemon-reload
    systemctl enable ddclient || echo "WARNING: Failed to enable DDClient"
    systemctl restart ddclient || echo "WARNING: Failed to restart DDClient"
    systemctl status ddclient || echo "WARNING: Failed to show DDClient status"

    XRDP_DIR="/home/$SUDO_USER/xrdp"
    $KIRA_SCRIPTS/git-pull.sh "https://github.com/neutrinolabs/xrdp.git" "$XRDP_VERSION" "$XRDP_DIR" || SUCCESS="false"
    FILE_HASH=$(CDHelper hash SHA256 -p="$XRDP_DIR" -x=true -r=true --silent=true -i="*.git,*.gitignore")
    EXPECTED_HASH="06d87e9938181245d27ceb88073decd08ed1b0e1781b65979e7e07c04eea3dac"
    [ "${SUCCESS,,}" != "true" ] && echo "INFO: Failed to download XRDP" && exit 0
    [ "${FILE_HASH}" != "${EXPECTED_HASH}" ] && echo "INFO: Faile do verify inegrity of the XRDP repository" && exit 0
   
    cd $XRDP_DIR
    ./bootstrap
    ./configure --enable-fuse --enable-jpeg --enable-rfxcodec
    make
    make install

    systemctl daemon-reload
    systemctl enable xrdp.service
    systemctl enable xrdp-sesman.service
    systemctl restart xrd

    # avoid an authenticate popup after inputting the username and password at the xrdp login screen on windows
    cat > "/etc/polkit-1/localauthority.conf.d/02-allow-colord.conf" <<EOL
polkit.addRule(function(action, subject) {
if ((action.id == “org.freedesktop.color-manager.create-device” || action.id == “org.freedesktop.color-manager.create-profile” || action.id == “org.freedesktop.color-manager.delete-device” || action.id == “org.freedesktop.color-manager.delete-profile” || action.id == “org.freedesktop.color-manager.modify-device” || action.id == “org.freedesktop.color-manager.modify-profile”) && subject.isInGroup(“{group}”))
{
return polkit.Result.YES;
}
});
EOL
   systemctl restart xrdp

    touch $SETUP_CHECK
else
    echo "INFO: Remote desktop protocol was already setup"
fi
