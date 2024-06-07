# Generate Secure Boot keys and cert

```shell

https://github.com/deionizedoatmeal/popdots
https://github.com/3lpsy/arch-galactic/blob/master/packages.sh

# Generate Secure Boot keys and certs.
arch-chroot /mnt sbctl create-keys

# Generate initramfs and install bootloader, everything signed for Secure Boot.
genfstab -U -P /mnt >> /mnt/etc/fstab
arch-chroot /mnt sbctl sign -s /usr/lib/systemd/boot/efi/systemd-bootx64.efi
arch-chroot /mnt dracut -f --uefi --regenerate-all
arch-chroot /mnt bootctl install # Remove this line and keep the line below if you prefer EFISTUB over systemd-boot.
# efibootmgr --create --disk ${TARGET_DISK_BLK} --part 1 --label "Meu Arch Linux" --loader /EFI/Linux/$(basename /mnt/efi/EFI/Linux/*.efi)

```
