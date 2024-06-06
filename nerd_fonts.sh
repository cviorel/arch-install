#!/bin/bash

# Update the package database
sudo pacman -Syu --noconfirm

# Install Git and jq if not already installed
sudo pacman -S --noconfirm git jq

# Create a directory for fonts
mkdir -p ~/.local/share/fonts

# Function to install a Nerd Font
install_nerd_font() {
    local font_name=$1
    local font_url=$2
    echo "Installing $font_name..."
    wget -O "$font_name.zip" "$font_url"
    unzip -q "$font_name.zip" -d "$font_name"
    cp -r "$font_name"/* ~/.local/share/fonts/
    rm -rf "$font_name" "$font_name.zip"
}

# Get the list of Nerd Fonts from GitHub API
echo "Fetching the list of Nerd Fonts..."
fonts_json=$(curl -s https://api.github.com/repos/ryanoasis/nerd-fonts/releases/latest)
fonts=($(echo "$fonts_json" | jq -r '.assets[].name' | grep '.zip$' | sed 's/.zip$//'))
font_urls=($(echo "$fonts_json" | jq -r '.assets[].browser_download_url' | grep '.zip$'))

# Install each Nerd Font
for i in "${!fonts[@]}"; do
    install_nerd_font "${fonts[$i]}" "${font_urls[$i]}"
done

# Refresh font cache
fc-cache -fv

echo "Nerd Fonts installation complete."
