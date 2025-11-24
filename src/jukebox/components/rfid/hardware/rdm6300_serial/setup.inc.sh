#!/usr/bin/env bash

source ../../../../../../installation/includes/02_helpers.sh

echo "Entering setup.inc.sh"

echo "Disabling login shell to be accessible over serial"

if [ "$(is_debian_version_at_least 12)" = true ]; then
    sudo raspi-config nonint do_serial_hw 1
    sudo raspi-config nonint do_serial_cons 1
else
    sudo raspi-config nonint do_serial 1
fi

echo "Enabling serial port hardware"
# Use helper function to get correct config.txt path for Bookworm compatibility
CONFIG_FILE=$(get_boot_config_path)
if [ ! -f "$CONFIG_FILE" ]; then
    echo "ERROR: Could not find config.txt file at $CONFIG_FILE"
    exit 1
fi
sudo raspi-config nonint set_config_var enable_uart 1 "$CONFIG_FILE"

echo -e "\nREBOOT for changes to take effect!\n"

