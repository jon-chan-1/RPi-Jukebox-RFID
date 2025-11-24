#!/usr/bin/env bash

_run_set_raspi_config() {
  # Source: https://raspberrypi.stackexchange.com/a/66939

  # Autologin
  log "  Enable Autologin for user"
  sudo raspi-config nonint do_boot_behaviour B2

  # Wait for network at boot
  # log "  Enable 'Wait for network at boot'"
  # sudo raspi-config nonint do_boot_wait 1

  # power management of wifi: switch off to avoid disconnecting
  log "  Disable Wifi power management to avoid disconnecting"
  # Use NetworkManager if available (Bookworm), otherwise fall back to iwconfig
  if command -v nmcli >/dev/null 2>&1 && systemctl is-active --quiet NetworkManager.service 2>/dev/null; then
    # NetworkManager: disable power saving via connection settings
    local wifi_interface="${CURRENT_INTERFACE:-wlan0}"
    local active_profile=$(nmcli -t -f DEVICE,CONNECTION device status | grep "^${wifi_interface}:" | cut -d':' -f2)
    if [ -n "$active_profile" ]; then
      sudo nmcli connection modify "$active_profile" wifi.powersave 2 2>/dev/null || true
      log "    Disabled WiFi power management via NetworkManager for $active_profile"
    else
      log "    Warning: Could not find active WiFi profile, skipping power management setting"
    fi
  elif command -v iwconfig >/dev/null 2>&1; then
    # Fallback to iwconfig for older systems
    sudo iwconfig wlan0 power off 2>/dev/null || log "    Warning: Could not disable WiFi power management"
  else
    log "    Warning: No WiFi management tool available (nmcli or iwconfig)"
  fi

  # On-board audio
  if [ "$DISABLE_ONBOARD_AUDIO" == true ]; then
    local configFile=$(get_boot_config_path)
    log "  Disable on-chip BCM audio"
    if grep -q -E "^dtparam=([^,]*,)*audio=(on|true|yes|1).*" "${configFile}" ; then
      local configFile_backup="${configFile}.backup.audio_on_$(date +%d.%m.%y_%H.%M.%S)"
      log "    Backup ${configFile} --> ${configFile_backup}"
      sudo cp "${configFile}" "${configFile_backup}"
      sudo sed -i "s/^\(dtparam=\([^,]*,\)*\)audio=\(on\|true\|yes\|1\)\(.*\)/\1audio=off\4/g" "${configFile}"
    else
      log "    On board audio seems to be off already. Not touching ${configFile}"
    fi
  fi
}

set_raspi_config() {
    run_with_log_frame _run_set_raspi_config "Set default raspi-config"
}
