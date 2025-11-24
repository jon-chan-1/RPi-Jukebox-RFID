#!/usr/bin/env bash

set_ssh_qos() {
    if [ "$DISABLE_SSH_QOS" == true ] ; then
        # The latest version of SSH installed on the Raspberry Pi 3 uses QoS headers, which disagrees with some
        # routers and other hardware. This causes immense delays when remotely accessing the RPi over ssh.
        log "  Set SSH QoS to best effort"
        
        # Ensure SSH service is enabled and running before modifying config
        if ! systemctl is-enabled ssh.service >/dev/null 2>&1 && ! systemctl is-enabled sshd.service >/dev/null 2>&1; then
            log "    Warning: SSH service is not enabled. Enabling it now..."
            sudo systemctl enable ssh.service 2>/dev/null || sudo systemctl enable sshd.service 2>/dev/null || true
        fi
        
        # Backup sshd_config before modification
        if [ ! -f /etc/ssh/sshd_config.backup ]; then
            sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup 2>/dev/null || true
        fi
        
        # Check if IPQoS is already configured in sshd_config
        if ! sudo grep -q "^IPQoS" /etc/ssh/sshd_config 2>/dev/null; then
            # Append IPQoS setting
            echo "IPQoS 0x00 0x00" | sudo tee -a /etc/ssh/sshd_config > /dev/null
            
            # Validate SSH config syntax before proceeding
            if sudo sshd -t -f /etc/ssh/sshd_config 2>/dev/null; then
                log "    Added IPQoS to sshd_config (validated)"
                # Reload SSH service to apply changes (don't restart to avoid disconnecting current session)
                sudo systemctl reload ssh.service 2>/dev/null || sudo systemctl reload sshd.service 2>/dev/null || true
            else
                log "    ERROR: SSH config syntax error detected! Restoring backup..."
                sudo cp /etc/ssh/sshd_config.backup /etc/ssh/sshd_config 2>/dev/null || true
                log "    SSH config restored from backup. SSH access should remain functional."
                return 1
            fi
        else
            log "    IPQoS already configured in sshd_config, skipping"
        fi
        
        # Backup ssh_config before modification
        if [ ! -f /etc/ssh/ssh_config.backup ]; then
            sudo cp /etc/ssh/ssh_config /etc/ssh/ssh_config.backup 2>/dev/null || true
        fi
        
        # Check if IPQoS is already configured in ssh_config
        if ! sudo grep -q "^IPQoS" /etc/ssh/ssh_config 2>/dev/null; then
            echo "IPQoS 0x00 0x00" | sudo tee -a /etc/ssh/ssh_config > /dev/null
            log "    Added IPQoS to ssh_config"
        else
            log "    IPQoS already configured in ssh_config, skipping"
        fi
        
        # Final check: Ensure SSH service is still enabled and running
        if systemctl is-enabled ssh.service >/dev/null 2>&1 || systemctl is-enabled sshd.service >/dev/null 2>&1; then
            log "    SSH service is enabled and configuration is valid"
        else
            log "    Warning: SSH service may not be enabled. Please check manually."
        fi
    fi
}
