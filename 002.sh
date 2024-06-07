#!/bin/bash

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
mkfs.fat -F32 ${DISK}1
mkfs.btrfs ${DISK}2 -f

# Mount the Btrfs partition
mount ${DISK}2 /mnt
btrfs su cr /mnt/@
btrfs su cr /mnt/@home
btrfs su cr /mnt/@var
btrfs su cr /mnt/@tmp
btrfs su cr /mnt/@.snapshots
umount /mnt

# Remount with subvolumes
mount -o noatime,compress=zstd,subvol=@ ${DISK}2 /mnt
mkdir -p /mnt/{boot,home,var,tmp,.snapshots}
mount -o noatime,compress=zstd,subvol=@home ${DISK}2 /mnt/home
mount -o noatime,compress=zstd,subvol=@var ${DISK}2 /mnt/var
mount -o noatime,compress=zstd,subvol=@tmp ${DISK}2 /mnt/tmp
mount -o noatime,compress=zstd,subvol=@.snapshots ${DISK}2 /mnt/.snapshots
mount ${DISK}1 /mnt/boot



# Install essential packages
pacstrap /mnt base linux linux-firmware

# Generate fstab
genfstab -U /mnt >> /mnt/etc/fstab

# Change root into the new system
arch-chroot /mnt /bin/bash <<EOF

# Set timezone
ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
hwclock --systohc

# Localization
echo "$LOCALE UTF-8" > /etc/locale.gen
locale-gen
echo "LANG=$LOCALE" > /etc/locale.conf
echo "KEYMAP=$KEYMAP" > /etc/vconsole.conf

# Network configuration
echo "$HOSTNAME" > /etc/hostname
cat <<EOT > /etc/hosts
127.0.0.1   localhost
::1         localhost
127.0.1.1   $HOSTNAME.localdomain $HOSTNAME
EOT

# Set root password
echo "root:$ROOT_PASSWORD" | chpasswd

# Install necessary packages
pacman -S --noconfirm grub efibootmgr networkmanager sudo xorg-server xorg-xinit openbox obconf obmenu lxappearance git firefox alacritty thunar xfce4-terminal neofetch fprintd aurulent-sans-font ttf-dejavu ttf-liberation noto-fonts

# Install GRUB
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg

# Enable NetworkManager
systemctl enable NetworkManager

# Create a new user
useradd -m -G wheel -s /bin/bash $USER_NAME
echo "$USER_NAME:$USER_PASSWORD" | chpasswd

# Allow wheel group to use sudo
sed -i 's/# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

# Set up .xinitrc for user
echo "exec openbox-session" > /home/$USER_NAME/.xinitrc
chown $USER_NAME:$USER_NAME /home/$USER_NAME/.xinitrc

# Set up Openbox configuration
sudo -u $USER_NAME mkdir -p /home/$USER_NAME/.config/openbox
sudo -u $USER_NAME cp /etc/xdg/openbox/{rc.xml,menu.xml,autostart} /home/$USER_NAME/.config/openbox/

# Install and configure themes and fonts
sudo -u $USER_NAME git clone https://github.com/addy-dclxvi/openbox-theme-collections /home/$USER_NAME/.themes
sudo -u $USER_NAME git clone https://github.com/addy-dclxvi/gtk-theme-collections /home/$USER_NAME/.themes
sudo -u $USER_NAME git clone https://github.com/addy-dclxvi/plymouth-theme-collections /home/$USER_NAME/.themes
sudo -u $USER_NAME git clone https://github.com/addy-dclxvi/icon-theme-collections /home/$USER_NAME/.icons

cat <<EOT > /home/$USER_NAME/.config/gtk-3.0/settings.ini
[Settings]
gtk-theme-name=Adapta-Nokto
gtk-icon-theme-name=Papirus-Dark
gtk-font-name=Aurulent Sans Regular 11
EOT

cat <<EOT > /etc/fonts/local.conf
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "fonts.dtd">
<fontconfig>
    <match target="pattern">
        <test qual="any" name="family">
            <string>serif</string>
        </test>
        <edit name="family" mode="assign" binding="same">
            <string>Aurulent Sans</string>
        </edit>
    </match>
    <match target="pattern">
        <test qual="any" name="family">
            <string>sans-serif</string>
        </test>
        <edit name="family" mode="assign" binding="same">
            <string>Aurulent Sans</string>
        </edit>
    </match>
    <match target="pattern">
        <test qual="any" name="family">
            <string>monospace</string>
        </test>
        <edit name="family" mode="assign" binding="same">
            <string>Aurulent Sans</string>
        </edit>
    </match>
</fontconfig>
EOT

chown -R $USER_NAME:$USER_NAME /home/$USER_NAME/.config

# Configure Openbox autostart for unified appearance
cat <<EOT > /home/$USER_NAME/.config/openbox/autostart
# Start the composite manager for transparency
picom -b

# Set wallpaper
nitrogen --restore &

# Start the panel
tint2 &

# Setup monitor configuration
xrandr --output eDP-1 --primary --mode 1920x1080 --dpi 96 \
       --output HDMI-1 --mode 2560x1440 --dpi 109 --right-of eDP-1 \
       --output DP-1 --mode 3840x2160 --dpi 163 --right-of HDMI-1
EOT

chown $USER_NAME:$USER_NAME /home/$USER_NAME/.config/openbox/autostart

# Enable and configure fprintd
systemctl enable fprintd

EOF

# Unmount and reboot
umount -R /mnt
echo "Arch Linux installation is complete. You can now reboot your system."
