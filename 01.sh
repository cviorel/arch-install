#!/bin/bash

# https://github.com/deionizedoatmeal/popdots
# https://github.com/3lpsy/arch-galactic/blob/master/packages.sh
https://github.com/addy-dclxvi
https://github.com/ilnanny/Artwork-Resources
https://github.com/ilnanny/backgrounds/tree/master
https://github.com/ilnanny
https://github.com/ilnanny/gentoo-openbox/tree/master/home/.fonts
https://github.com/zakuradev



# Themes
# git clone https://github.com/reorr/my-theme-collection.git design/themes-reoor
# git clone https://github.com/zakuradev/openbox-themes design/openbox-theme-zakuradev
# git clone https://github.com/Dr-Noob/Arc-Dark-OSX design/ArcDarkOSX
# git clone https://github.com/logico/typewriter-gtk design/typewriter
# git clone https://github.com/addy-dclxvi/tint2-theme-collections design/tint2-themes
# git clone https://github.com/ilnanny/XThemes design/xthemes-ilnanny
# git clone https://github.com/YurinDoctrine/.config.git design/themes-gnomelike
# git clone https://github.com/jr20xx/Mint-O-Themes design/mint-openbox


# Variables
# DISK="/dev/nvme0n1"
DISK="/dev/sda"
HOSTNAME="ThinkPad-X1"
USERNAME="cviorel"
PASSWORD="password"

TIMEZONE=$(curl -s https://ipapi.co/timezone)
if [[ -z $TIMEZONE ]] ; then
	TIMEZONE="Europe/Brussels"
fi

# Update the system clock
timedatectl set-ntp true

# Zap all on disk
sgdisk -Z $DISK

# Remove all partitions
wipefs -a $DISK

# Create a new GPT disk with 2048 alignment
sgdisk -a 2048 -o $DISK

# Partition the disk
parted $DISK --script mklabel gpt
parted $DISK --script mkpart ESP fat32 1MiB 513MiB
parted $DISK --script set 1 boot on
parted $DISK --script mkpart primary btrfs 513MiB 100%

# Reread partition table to ensure it is correct
sync && partprobe ${DISK} && sleep 2

# Format the partitions
mkfs.fat -F32 ${DISK}p1
mkfs.btrfs ${DISK}p2 -f

# Mount the Btrfs partition
mount ${DISK}p2 /mnt
btrfs su cr /mnt/@
btrfs su cr /mnt/@home
btrfs su cr /mnt/@var
btrfs su cr /mnt/@tmp
btrfs su cr /mnt/@.snapshots
umount /mnt

# Remount with subvolumes
mount -o noatime,compress=zstd,subvol=@ ${DISK}p2 /mnt
mkdir -p /mnt/{boot,home,var,tmp,.snapshots}
mount -o noatime,compress=zstd,subvol=@home ${DISK}p2 /mnt/home
mount -o noatime,compress=zstd,subvol=@var ${DISK}p2 /mnt/var
mount -o noatime,compress=zstd,subvol=@tmp ${DISK}p2 /mnt/tmp
mount -o noatime,compress=zstd,subvol=@.snapshots ${DISK}p2 /mnt/.snapshots
mount ${DISK}p1 /mnt/boot

# Find the best mirrors for installation
reflector --verbose -l 10 --sort rate --protocol https --save /etc/pacman.d/mirrorlist

# Install base system
pacstrap -K /mnt base linux linux-firmware btrfs-progs

# Generate fstab
genfstab -U /mnt >>/mnt/etc/fstab

# Change root
arch-chroot /mnt /bin/bash <<EOF

# Set timezone
ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
hwclock --systohc

# Localization
echo "en_US.UTF-8 UTF-8" > /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

# Network configuration
echo "$HOSTNAME" > /etc/hostname
echo "127.0.0.1   localhost" >> /etc/hosts
echo "::1         localhost" >> /etc/hosts
echo "127.0.1.1   $HOSTNAME.localdomain $HOSTNAME" >> /etc/hosts

# Initramfs
mkinitcpio -P

# Root password
echo "root:$PASSWORD" | chpasswd

# Configure pacman to color the output
cp /etc/pacman.conf /etc/pacman.conf_`date +'%Y-%m-%d'`
sed -i 's/#Color/Color/g' /etc/pacman.conf

# Set pacman parallel downloads to 5
sed -i "/^#ParallelDownloads =/c\ParallelDownloads = 5" /etc/pacman.conf

# Bootloader
pacman -S --noconfirm grub efibootmgr

cp /etc/default/grub /etc/default/grub_`date +'%Y-%m-%d'`
sed -i '/^GRUB_GFXMODE=/c\GRUB_GFXMODE=1920x1080,auto' /etc/default/grub
sed -i '/^GRUB_GFXPAYLOAD_LINUX=/c\GRUB_GFXPAYLOAD_LINUX=keep' /etc/default/grub
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id='Arch Linux'
grub-mkconfig -o /boot/grub/grub.cfg

# Create user
useradd -m -G wheel -s /bin/bash $USERNAME
echo "$USERNAME:$PASSWORD" | chpasswd
echo "%wheel ALL=(ALL) ALL" >> /etc/sudoers

# Install necessary packages
pacman -S --noconfirm intel-ucode \
	mesa xclip xorg-server xorg-xinit xorg-xdpyinfo xorg-xev xorg-xkill xorg-xlsfonts xorg-xrandr xorg-xset xorg-xsetroot \
	pipewire{,-alsa,-pulse,-jack} wireplumber \
	man-db man-pages texinfo \
	lightdm lightdm-gtk-greeter acpid \
	openbox obconf menumaker archlinux-xdg-menu \
	xdg-user-dirs xdg-utils git lsof \
	avahi bluez bluez-utils \
	networkmanager network-manager-applet nm-connection-editor \
	tlp ntp fprintd sudo ntfs-3g \
	arandr autorandr \
	iwd openssh pcmanfm gnome-menus leafpad \
	firefox chromium \
	feh tint2 gpicview gmrun fping dzen2 samba vlc xpdf bash-completion \
	pipewire wireplumber pipewire-audio pipewire-alsa pipewire-pulse pipewire-jack alsa-utils pavucontrol \
	otf-firamono-nerd otf-monaspace otf-aurulent-nerd \
	noto-fonts noto-fonts-emoji powerline-fonts \
	ttf-anonymouspro-nerd ttf-cascadia-code-nerd ttf-envycoder-nerd \
	adobe-source-code-pro-fonts \
	xcompmgr geany code xsettingsd brightnessctl \
	gtk-engines gtk-engine-murrine \
	hsetroot rdesktop vim keychain \
	arc-gtk-theme arc-icon-theme papirus-icon-theme obsidian-icon-theme \
	cups cups-pdf \
	nvidia nvidia-utils nvidia-settings \
	volumeicon osmo sox btop \
	rxvt-unicode urxvt-perls

# Enable services
systemctl enable tlp.service
systemctl enable ntpd.service
systemctl enable lightdm.service
systemctl enable NetworkManager.service
systemctl enable bluetooth
systemctl enable avahi-daemon.service

mkdir -p /home/$USERNAME/.config/openbox
cp -a /etc/xdg/openbox /home/$USERNAME/.config/

echo '
(sleep 1s && tint2) &
(sleep 1s && nm-applet) &
(sleep 1s && volumeicon) &
(sleep 1s && osmo) &
(sleep 2s && setxkbmap -option grp:switch "us","ro(std)") &
(sleep 5s && xxkb) &
' | tee -a /home/$USERNAME/.config/openbox/autostart

echo "
! ~/.Xresources

! General settings
Xft.dpi: 96
Xft.antialias: true
Xft.hinting: true
Xft.hintstyle: hintfull
Xft.rgba: rgb
Xft.lcdfilter: lcddefault

! Font settings
URxvt*font: xft:AurulentSansM Nerd Font Mono:pixelsize=12:antialias=true:hinting=true
URxvt*boldFont: xft:AurulentSansM Nerd Font Mono:bold:pixelsize=12:antialias=true:hinting=true
URxvt*italicFont: xft:AurulentSansM Nerd Font Mono:italic:pixelsize=12:antialias=true:hinting=true
URxvt*boldItalicFont: xft:AurulentSansM Nerd Font Mono:bold:italic:pixelsize=12:antialias=true:hinting=true

! Terminal colors
URxvt*foreground: #dcdcdc
URxvt*background: #1c1c1c
URxvt*cursorColor: #dcdcdc
URxvt*colorUL: #dcdcdc

! Black
URxvt*color0: #1c1c1c
URxvt*color8: #4c4c4c

! Red
URxvt*color1: #af5f5f
URxvt*color9: #ff8787

! Green
URxvt*color2: #5f875f
URxvt*color10: #87d787

! Yellow
URxvt*color3: #87875f
URxvt*color11: #ffffaf

! Blue
URxvt*color4: #5f87af
URxvt*color12: #87afff

! Magenta
URxvt*color5: #8787af
URxvt*color13: #d7afff

! Cyan
URxvt*color6: #5fafaf
URxvt*color14: #87ffff

! White
URxvt*color7: #dcdcdc
URxvt*color15: #ffffff

! Scrollbar settings
URxvt*scrollBar: false

! Misc settings
URxvt*saveLines: 10000
URxvt*internalBorder: 6
URxvt*externalBorder: 6
URxvt*urgentOnBell: true
URxvt*visualBell: true
URxvt*loginShell: true

! OpenBox-specific settings
URxvt*perl-ext-common: default,matcher
URxvt*urlLauncher: firefox
URxvt*matcher.button: 1

! Enable clickable URLs
URxvt*keysym.Control-Shift-C: eval:selection_to_clipboard
URxvt*keysym.Control-Shift-V: eval:paste_clipboard
URxvt*keysym.M-Delete: \033[3;3~

! Extensions
URxvt.perl-ext-common:      default,clipboard,url-select,keyboard-select
URxvt.url-select.launcher:  chromium
URxvt.url-select.underline: true
URxvt.keysym.M-u:           perl:url-select:select_next
URxvt.keysym.M-Escape:      perl:keyboard-select:activate
URxvt.keysym.M-s:           perl:keyboard-select:search

! XTerm ----------------------------------------------------------------
XTerm*geometry:         140x50
XTerm*scrollBar:        false
XTerm*dynamicColors:    true
XTerm*saveLines:        2000
XTerm*eightBitInput:    false
XTerm*iconName:         XTerm

! Enables True-Type rendering
XTerm*renderFont:   true
XTerm*faceName:     AurulentSansM Nerd Font Mono
XTerm*faceSize:     10
XTerm*foreground:   #ffffff
XTerm*background:   black

! Tango Color Scheme
XTerm*color0:       #2e3436
XTerm*color1:       #cc0000
XTerm*color2:       #4e9a06
XTerm*color3:       #c4a000
XTerm*color4:       #3465a4
XTerm*color5:       #75507b
XTerm*color6:       #0b939b
XTerm*color7:       #d3d7cf
XTerm*color8:       #555753
XTerm*color9:       #ef2929
XTerm*color10:      #8ae234
XTerm*color11:      #fce94f
XTerm*color12:      #729fcf
XTerm*color13:      #ad7fa8
XTerm*color14:      #00f5e9
XTerm*color15:      #eeeeec
" | tee /home/$USERNAME/.Xresources

echo '
#!/usr/bin/env bash

xcompmgr -cCfF -t-5 -l-5 -r4.2 -o.55 -D6 &

xrdb -merge .Xresources &
eval `cat $HOME/.fehbg` &

export OOO_FORCE_DESKTOP=gnome
export LANG="en_US.UTF-8"
export LC_ALL="en_US.UTF-8"
export LANGUAGE="en_US.UTF-8"
export LC_CTYPE="en_US.UTF-8"

exec openbox-session
' | tee /home/$USERNAME/.xinitrc

echo'
# ~.xxkbrc:
#
XXkb.image.path: /usr/share/xxkb/
XXkb.mainwindow.type: tray
XXkb.group.base: 1
XXkb.group.alt: 2
XXkb.mainwindow.enable: yes
XXkb.mainwindow.image.1: en15.xpm
XXkb.mainwindow.image.2:
XXkb.mainwindow.image.3:
XXkb.mainwindow.image.4:
XXkb.mainwindow.appicon: yes
XXkb.mainwindow.geometry: 20x20+2+2
XXkb.mainwindow.in_tray: GNOME2
XXkb.button.enable: no
XXkb.app_list.wm_class_name.start_alt:
XXkb.controls.add_when_start: yes
XXkb.controls.add_when_create: yes
XXkb.controls.add_when_change: no
XXkb.controls.focusout: no
XXkb.mainwindow.xpm.1: en15.xpm
XXkb.mainwindow.xpm.2:
XXkb.mainwindow.label.enable: no
' | tee /home/$USERNAME/.xxkbrc

#chown -R $USERNAME:$USERNAME /home/$USERNAME

# Exit chroot
EOF

# Unmount and reboot
umount -R /mnt
# reboot
