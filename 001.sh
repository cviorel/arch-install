#!/bin/bash

# Variables
DISK="/dev/nvme0n1"
HOSTNAME="ThinkPad-X1"
USERNAME="cviorel"
PASSWORD="password"

# Update the system clock
timedatectl set-ntp true

# Zap all on disk
sgdisk -Z $DISK # zap all on disk

# Remove all partitions
wipefs -a $DISK

# Create a new GPT disk with 2048 alignment
sgdisk -a 2048 -o $DISK

# Partition the disk
parted $DISK --script mklabel gpt
parted $DISK --script mkpart ESP fat32 1MiB 513MiB
parted $DISK --script set 1 boot on
parted $DISK --script mkpart primary btrfs 513MiB 100%

partprobe ${DISK} # reread partition table to ensure it is correct

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


# Install base system
pacstrap /mnt base linux linux-firmware btrfs-progs

# Generate fstab
genfstab -U /mnt >>/mnt/etc/fstab

# Change root
arch-chroot /mnt /bin/bash <<EOF

# Set timezone
ln -sf /usr/share/zoneinfo/Region/City /etc/localtime
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

# Bootloader
pacman -S --noconfirm grub efibootmgr
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg

# Create user
useradd -m -G wheel -s /bin/bash $USERNAME
echo "$USERNAME:$PASSWORD" | chpasswd
echo "%wheel ALL=(ALL) ALL" >> /etc/sudoers

# Install necessary packages
pacman -S --noconfirm xorg-server xorg-xinit openbox obconf menumaker archlinux-xdg-menu \
    lightdm lightdm-gtk-greeter \
    nvidia nvidia-utils nvidia-settings avahi bluez bluez-utils \
    networkmanager network-manager-applet nm-connection-editor ntp \
    xorg-xrandr arandr lxrandr-gtk3 autorandr \
    iwd xorg-xdpyinfo openssh pcmanfm gnome-menus firefox leafpad \
    rxvt-unicode \
    feh tint2 gpicview gmrun fping dzen2 samba vlc xpdf bash-completion sudo \
    fprintd \
    pipewire wireplumber pipewire-audio pipewire-alsa pipewire-pulse pipewire-jack \
    otf-firamono-nerd noto-fonts noto-fonts-emoji otf-monaspace ttf-anonymouspro-nerd \
    ttf-cascadia-code-nerd ttf-envycoder-nerd otf-aurulent-nerd adobe-source-code-pro-fonts \
    xdg-utils efibootmgr xcompmgr xorg-xlsfonts osmo geany xorg-xcalc \
    gtk-engines gtk-engine-murrine \
    leafpad hsetroot rdesktop vim \
    arc-icon-theme papirus-icon-theme obsidian-icon-theme 

# Enable services
systemctl enable ntpd.service
systemctl enable lightdm.service
systemctl enable NetworkManager.service
systemctl enable bluetooth
systemctl enable avahi-daemon.service

mkdir -p /home/$USERNAME/.config/openbox
cp -a /etc/xdg/openbox /home/$USERNAME/.config/

echo '
(sleep 2s && tint2) &
' | tee -a /home/$USERNAME/.config/openbox/autostart

echo "
# ~/.Xresources
Xft.dpi: 192

! These might also be useful depending on your monitor and personal preference:
Xft.autohint: 0
Xft.lcdfilter:  lcddefault
Xft.hintstyle:  hintfull
Xft.hinting: 1
Xft.antialias: 1
Xft.rgba: rgb
" > /home/$USERNAME/.Xresources

touch /home/$USERNAME/.xinitrc
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
' | tee -a /home/$USERNAME/.xinitrc

echo "xrdb -merge ~/.Xresources" | tee -a /home/$USERNAME/.xinitrc

# Exit chroot
EOF

# Unmount and reboot
umount -R /mnt
# reboot

