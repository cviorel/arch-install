#!/bin/bash

# Update the package database
sudo pacman -Syu --noconfirm

# Install Wi-Fi support
sudo pacman -S --noconfirm networkmanager iw wpa_supplicant dialog

# Enable and start NetworkManager service
sudo systemctl enable NetworkManager
sudo systemctl start NetworkManager

# Install Bluetooth support
sudo pacman -S --noconfirm bluez bluez-utils

# Enable and start Bluetooth service
sudo systemctl enable bluetooth
sudo systemctl start bluetooth

# Install Bluetooth manager
sudo pacman -S --noconfirm blueman

# Reboot to apply changes
echo "Installation complete. The system will reboot in 10 seconds."
sleep 10
sudo reboot
