#!/bin/bash -e


# This file is part of PrawnOS (https://www.prawnos.com)
# Copyright (c) 2018 Hal Emmerich <hal@halemmerich.com>

# PrawnOS is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License version 2
# as published by the Free Software Foundation.

# PrawnOS is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with PrawnOS.  If not, see <https://www.gnu.org/licenses/>.


### SHARED CONST AND VARS
# TODO: when these scripts are packaged, place these in a shared script instead of in every file that needs them
device_veyron_speedy="Google Speedy"
device_veyron_minnie="Google Minnie"
device_gru_kevin="Google Kevin"
device_gru_bob="Google Bob"

get_device() {
    local device=$(tr -d '\0' < /sys/firmware/devicetree/base/model)
    echo $device
}

get_emmc_devname() {
    local device=$(get_device)
    case "$device" in
        $device_veyron_speedy) local devname=mmcblk2;;
        $device_veyron_minnie) local devname=mmcblk2;;
        $device_gru_kevin) local devname=mmcblk1;;
        $device_gru_bob) local devname=mmcblk1;;
        * ) echo "Unknown device! can't determine emmc devname. Please file an issue with the output of fdisk -l if you get this on a supported device"; exit 1;;
    esac
    echo $devname
}


get_sd_devname() {
    local device=$(get_device)
    case "$device" in
        $device_veyron_speedy) local devname=mmcblk0;;
        $device_veyron_minnie) local devname=mmcblk0;;
        $device_gru_kevin) local devname=mmcblk0;;
        $device_gru_bob) local devname=mmcblk0;;
        * ) echo "Unknown device! can't determine sd card devname. Please file an issue with the output of fdisk -l if you get this on a supported device"; exit 1;;
    esac
    echo $devname
}

### END SHARED CONST AND VARS


DIR=/InstallResources
# Import the package lists
source $DIR/package_lists.sh

cat $DIR/icons/ascii-icon.txt
echo ""

while true; do
    read -r -p "Install (X)fce4, (L)xqt, (G)nome or (S)way, if unsure choose (X)fce: " XL
    case $XL in
        [Gg]* ) DE=gnome; break;;
        [Xx]* ) DE=xfce; break;;
        [Ll]* ) DE=lxqt; break;;
        [Ss]* ) DE=sway; break;;
	* ) echo "Please answer (X)fce4, (L)xqt, (G)nome or (S)way";;
    esac
done

#Set the timezone
dpkg-reconfigure tzdata

#Install shared packages
DEBIAN_FRONTEND=noninteractive apt install -y ${base_debs_download[@]}
DEBIAN_FRONTEND=noninteractive apt install -y ${mesa_debs_download[@]}
DEBIAN_FRONTEND=noninteractive apt install -y ${prawnos_base_debs_prebuilt_download[@]}

[ "$DE" = "gnome" ] && apt install -y ${gnome_debs_download[@]}
[ "$DE" = "xfce" ] && apt install -y ${xfce_debs_download[@]} ${prawnos_base_debs_prebuilt_install[@]}
[ "$DE" = "lxqt" ] && apt install -y ${lxqt_debs_download[@]}
[ "$DE" = "sway" ] && apt install -y ${sway_debs_download[@]}

#install the keymap by patching xkb, then bindings work for any desktop environment
#cp $DIR/xkb/compat/* /usr/share/X11/xkb/compat/
#cp $DIR/xkb/keycodes/* /usr/share/X11/xkb/keycodes/
#cp $DIR/xkb/symbols/* /usr/share/X11/xkb/symbols/

#patch /usr/share/X11/xkb/rules/base < $DIR/xkb/rules/base.patch
#patch /usr/share/X11/xkb/rules/base.lst < $DIR/xkb/rules/base.lst.patch
#patch /usr/share/X11/xkb/rules/base.xml < $DIR/xkb/rules/base.xml.patch
#patch /usr/share/X11/xkb/rules/evdev < $DIR/xkb/rules/evdev.patch
#patch /usr/share/X11/xkb/rules/evdev.lst < $DIR/xkb/rules/evdev.lst.patch
#patch /usr/share/X11/xkb/rules/evdev.xml < $DIR/xkb/rules/evdev.xml.patch

#patch /usr/share/X11/xkb/symbols/gb < $DIR/xkb/symbols/gb.patch
#patch /usr/share/X11/xkb/symbols/us < $DIR/xkb/symbols/us.patch

#cp  $DIR/xkb/keyboard /etc/default/keyboard

#disable ertm for csr8510 bluetooth, issue #117
echo "module/bluetooth/parameters/disable_ertm = 1" > /etc/sysfs.conf

if [ "$DE" = "gnome" ]
then
  #install firefox-esr default settings
  cp $DIR/firefox-esr/prawn-settings.js /usr/lib/firefox-esr/defaults/pref/
  cp $DIR/firefox-esr/prawn.cfg /usr/lib/firefox-esr/

  #TODO: a config file way to do the following would be nice, so that we can install the configs now instead
  # of having to run the following commands after login
  #Natural scrolling is un-natural
  # gsettings set org.gnome.desktop.peripherals.touchpad natural-scroll false
  #Tap to click is natural
  # gsettings set org.gnome.desktop.peripherals.touchpad tap-to-click true
fi

if [ "$DE" = "xfce" ]
then
  # remove light-locker, as it is broken on this machine. See issue https://github.com/SolidHal/PrawnOS/issues/56#issuecomment-504681175
  apt remove -y light-locker
  apt purge -y light-locker

  #Install packages not in an apt repo
  dpkg -i $DIR/xfce-themes/*

  #Copy in xfce4 default settings
  cp -f $DIR/xfce-config/xfce-perchannel-xml/* /etc/xdg/xfce4/xfconf/xfce-perchannel-xml/
  cp -f $DIR/xfce-config/panel/* /etc/xdg/xfce4/panel/

  #Copy in lightdm/light greeter settings
  cp -f $DIR/icons/icon-small.png /etc/lightdm/icon.png
  chmod 644 /etc/lightdm/icon.png
  cp -f $DIR/xfce-config/lightdm/* /etc/lightdm/


  #Patch xflock4 to activate xsecurelock
  patch /usr/bin/xflock4 < $DIR/xfce-config/xflock-xsecurelock.patch

  #Copy in wallpapers
  rm /usr/share/images/desktop-base/default && cp $DIR/wallpapers/* /usr/share/images/desktop-base/

  #Install libinput-gestures and xfdashboard "packages"
  cd $DIR/packages/
  dtrx libinput-gestures.tar.gz
  cd libinput-gestures
  make install
  cd ..

  #Add libinput-gestures config and autostart
  cp $DIR/xfce-config/libinput-gestures/libinput-gestures.conf /etc/
  cp $DIR/xfce-config/libinput-gestures/libinput-gestures.desktop /etc/xdg/autostart/

  #Make plank autostart
  cp $DIR/xfce-config/plank/plank.desktop /etc/xdg/autostart/

  #install plank launcher
  mkdir -p /etc/skel/.config/plank/dock1/launchers/
  cp -rf $DIR/xfce-config/plank/plank-launchers/* /etc/skel/.config/plank/dock1/launchers/

  #install firefox-esr default settings
  cp $DIR/firefox-esr/prawn-settings.js /usr/lib/firefox-esr/defaults/pref/
  cp $DIR/firefox-esr/prawn.cfg /usr/lib/firefox-esr/

  #Install inputrc
  cp -rf $DIR/xfce-config/inputrc/.inputrc /etc/skel/

  #Install brightness control scripts
  cp $DIR/xfce-config/brightness/backlight_* /usr/sbin/
fi

if [ "$DE" = "sway" ]
then
  cp $DIR/sway/config /etc/sway/config
  cp $DIR/sway/status /usr/bin/sway_status
  chmod a+x /usr/bin/sway_status
fi


#Copy in acpi, pulse audio, trackpad settings, funtion key settings
device_model=$(get_device)

if [[ $device_model == $device_veyron_speedy ]] || [[ $device_model == $device_veyron_minnie ]]
then
    cp -rf $DIR/veyron/default.pa /etc/pulse/default.pa
    # Disable flat-volumes in pulseaudio, fixes broken sound for some sources in firefox
    echo "flat-volumes = no" > /etc/pulse/daemon.conf
    cp -rf $DIR/veyron/sound.sh /etc/acpi/sound.sh
    cp -rf $DIR/veyron/headphone-acpi-toggle /etc/acpi/events/headphone-acpi-toggle
    mkdir -p /etc/X11/xorg.conf.d/
    cp -rf $DIR/30-touchpad.conf /etc/X11/xorg.conf.d/
fi

if [[ $device_model == $device_gru_kevin ]] || [[ $device_model == $device_gru_bob ]]
then
    echo "load-module module-alsa-sink device=sysdefault" > /etc/pulse/default.pa
fi


apt clean -y && apt autoremove --purge -y

#reload the CA certificate symlinks
update-ca-certificates --fresh

#enable periodic TRIM
cp /lib/systemd/system/fstrim.{service,timer} /etc/systemd/system
systemctl enable fstrim.timer

dmesg -D

echo ""
echo ""
echo ""

cat $DIR/icons/ascii-icon.txt
echo ""
echo "*************Welcome To PrawnOS*************"
echo ""
#Have the user set a root password
echo "-----Enter a password for the root user-----"
until passwd
do
    echo "-----Enter a password for the root user-----"
    passwd
done

#Force a safe username
while true; do
    echo "-----Enter new username:-----"
    read -r username
    #ensure no whitespace
    case $username in *\ *) echo usernames may not contain whitespace;;  *) break;; esac
done
until adduser $username --gecos ""
do
    while true; do
        echo "-----Enter new username:-----"
        read -r username
        #ensure no whitespace
        case $username in *\ *) echo usernames may not contain whitespace;;  *) break;; esac
    done
done

#install hwdb file for iio-sensor-proxy to work
printf 'sensor:modalias:platform:*\n ACCEL_MOUNT_MATRIX=-1, 0, 0; 0, -1, 0; 0, 0, -1\n' > /etc/udev/hwdb.d/61-sensor-local.hwdb
systemd-hwdb update
udevadm trigger

#make bootsplash not disappear again
systemctl mask plymouth-start
dpkg-reconfigure -f noninteractive console-setup
grep -v setfont /etc/console-setup/cached_setup_font.sh > /tmp/cached_setup_font.sh
cp /tmp/cached_setup_font.sh /etc/console-setup/cached_setup_font.sh

mkdir -p /opt/git
cd /opt/git/
cd c100pa-daemon
make
make install
systemctl enable c100pa-daemon

usermod -a -G sudo,netdev,input,video,bluetooth $username

dmesg -E

