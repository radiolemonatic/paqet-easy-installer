#!/usr/bin/env bash

# Run everything inside a subshell
(
    ###############################################################################
    # COLORS & HELPERS
    ###############################################################################

    BOLD="\e[1m"
    BLUE="\e[34m"
    GREEN="\e[32m"
    YELLOW="\e[33m"
    RED="\e[31m"
    NC="\e[0m"

    header() { echo -e "\n${BOLD}${BLUE}==============================\n$1\n==============================${NC}\n"; }
    info()   { echo -e "${GREEN}[INFO]${NC} $1"; }
    warn()   { echo -e "${YELLOW}[WARN]${NC} $1"; }

    # Trap Ctrl+C: stop this subshell only
    trap 'echo; warn "Ctrl+C pressed. Script stopped safely." ; return 0 2>/dev/null || exit 0' SIGINT

    ###############################################################################
    # STEP 0 - CHECK IF PAQET EXISTS
    ###############################################################################

    header "CHECKING PAQET INSTALLATION"

    if [[ ! -f /opt/paqet && ! -f /opt/config.yaml ]]; then
        warn "Paqet server not found on this system."
        warn "Nothing to uninstall. Exiting safely."
        return 0 2>/dev/null || exit 0
    else
        info "Paqet detected. Proceeding with uninstall."
    fi

    ###############################################################################
    # STEP 1 - INTRO & CONFIRMATION
    ###############################################################################

    header "PAQET SERVER UNINSTALLER"

    warn "This will remove Paqet server, systemd service, and iptables rules."
    warn "SSH session will NOT be closed under any circumstances."
    echo

    read -p "Type 'yes' to continue: " CONFIRM
    CONFIRM=$(echo "$CONFIRM" | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')

    if [[ "$CONFIRM" != "yes" ]]; then
        warn "You did not type 'yes'. Script will exit safely."
        return 0 2>/dev/null || exit 0
    fi

    ###############################################################################
    # STEP 2 - DETECT CONFIG
    ###############################################################################

    header "DETECTING CONFIG"

    CONFIG_PATH="/opt/config.yaml"

    if [[ -f "$CONFIG_PATH" ]]; then
        SERVER_PORT=$(grep -E 'listen:|addr:' "$CONFIG_PATH" | grep ':' | tail -n1 | awk -F':' '{print $NF}')
        INTERFACE=$(grep 'interface:' "$CONFIG_PATH" | awk '{print $2}' | tr -d '"')
    else
        warn "Config file not found. Using defaults."
        SERVER_PORT="443"
        INTERFACE=$(ip route show default | awk '{print $5}')
    fi

    info "Detected Paqet port : $SERVER_PORT"
    info "Detected interface : $INTERFACE"

    ###############################################################################
    # STEP 3 - SSH SAFETY CHECK
    ###############################################################################

    header "SSH SAFETY CHECK"

    SSH_PORTS=$(ss -tnp | grep sshd | awk '{print $4}' | awk -F':' '{print $NF}' | sort -u || true)

    if echo "$SSH_PORTS" | grep -qx "$SERVER_PORT"; then
        warn "Active SSH connection detected on Paqet port $SERVER_PORT."
        echo
        read -p "Type 'continue' to proceed anyway: " FORCE
        FORCE=$(echo "$FORCE" | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')
        if [[ "$FORCE" != "continue" ]]; then
            warn "Script exiting safely without touching SSH."
            return 0 2>/dev/null || exit 0
        fi
    fi

    ###############################################################################
    # STEP 4 - REMOVE SYSTEMD SERVICE
    ###############################################################################

    header "REMOVING SYSTEMD SERVICE"

    if systemctl list-unit-files | grep -q '^paqet.service'; then
        systemctl stop paqet || warn "Failed to stop service (ignored)"
        systemctl disable paqet || warn "Failed to disable service (ignored)"
        rm -f /etc/systemd/system/paqet.service
        systemctl daemon-reload || warn "Failed to reload systemd (ignored)"
        info "Systemd service removed"
    else
        warn "Systemd service not found"
    fi

    ###############################################################################
    # STEP 5 - REMOVE IPTABLES RULES
    ###############################################################################

    header "REMOVING IPTABLES RULES"

    iptables -t raw    -D PREROUTING -p tcp --dport "$SERVER_PORT" -j NOTRACK 2>/dev/null || true
    iptables -t raw    -D OUTPUT     -p tcp --sport "$SERVER_PORT" -j NOTRACK 2>/dev/null || true
    iptables -t mangle -D OUTPUT     -p tcp --sport "$SERVER_PORT" --tcp-flags RST RST -j DROP 2>/dev/null || true

    info "iptables rules removed"

    if command -v netfilter-persistent >/dev/null 2>&1; then
        netfilter-persistent save || warn "Failed to persist iptables cleanup (ignored)"
    fi

    ###############################################################################
    # STEP 6 - REMOVE FILES
    ###############################################################################

    header "REMOVING FILES"

    rm -f /opt/paqet
    rm -f /opt/config.yaml

    info "Binary and configuration removed"

    ###############################################################################
    # STEP 7 - NIC OFFLOADING INFO
    ###############################################################################

    header "NIC OFFLOADING INFO"

    warn "NIC offloading (GRO/GSO/TSO) was disabled during installation."
    warn "This script does NOT re-enable offloading automatically."
    warn "Re-enable manually if required."
    info "Example command:"
    echo "  ethtool -K $INTERFACE gro on gso on tso on"

    ###############################################################################
    # DONE
    ###############################################################################

    header "UNINSTALL COMPLETE"
    info "Paqet server has been removed safely. SSH session is fully intact."

)  # end subshell
