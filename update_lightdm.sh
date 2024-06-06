#!/bin/bash

# Set variables for font and background image
FONT="YourFontName"                             # Replace with your desired font name
BACKGROUND_IMAGE="/path/to/your/background.jpg" # Replace with the path to your background image

# Configuration file path for lightdm-webkit-theme-litarvan
CONFIG_FILE="/usr/share/lightdm-webkit/themes/litarvan/js/config.js"

# Check if the configuration file exists
if [[ ! -f $CONFIG_FILE ]]; then
    echo "Configuration file not found at $CONFIG_FILE"
    exit 1
fi

# Backup the original configuration file
cp $CONFIG_FILE ${CONFIG_FILE}.bak

# Update font in the configuration file
sed -i "s/\"font\": \".*\"/\"font\": \"$FONT\"/" $CONFIG_FILE

# Update background image in the configuration file
sed -i "s|\"background\": \".*\"|\"background\": \"$BACKGROUND_IMAGE\"|" $CONFIG_FILE

echo "Font and background image updated in $CONFIG_FILE"

# Multiple monitors configuration using xrandr
# Detect connected monitors
MONITORS=($(xrandr --query | grep " connected" | awk '{ print$1 }'))

# Number of connected monitors
NUM_MONITORS=${#MONITORS[@]}

if [[ $NUM_MONITORS -lt 2 ]]; then
    echo "Less than two monitors detected. Exiting multi-monitor configuration."
    exit 1
fi

# Configure monitors (example configuration)
# Adjust positions and resolutions as per your requirements
xrandr --output ${MONITORS[0]} --primary --mode 1920x1080 --pos 0x0 --rotate normal
xrandr --output ${MONITORS[1]} --mode 1920x1080 --pos 1920x0 --rotate normal

echo "Multi-monitor configuration applied"

# Restart LightDM to apply changes
sudo systemctl restart lightdm

echo "LightDM restarted to apply new configuration"

exit 0
