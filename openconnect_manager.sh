#!/usr/bin/env bash

# OpenConnect VPN Client Manager
# A menu-driven script to manage OpenConnect VPN connections

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYTHON_SCRIPT="$SCRIPT_DIR/openconnect_udp.py"
CONFIG_FILE="$HOME/.openconnect_config"

connect_vpn() {
    echo -e "\e[32m=== Connect to VPN ===\e[39m"
    
    if [[ -f "$CONFIG_FILE" ]]; then
        echo "Loading saved configuration..."
        source "$CONFIG_FILE"
        echo "Server: $VPN_SERVER"
        echo "Username: $VPN_USERNAME"
        read -p "Use saved config? (y/n): " use_saved
        if [[ "$use_saved" != "y" ]]; then
            read_vpn_config
        fi
    else
        read_vpn_config
    fi
    
    # Build command
    CMD="sudo python3 $PYTHON_SCRIPT connect $VPN_SERVER --username $VPN_USERNAME"
    
    if [[ -n "$VPN_AUTHGROUP" ]]; then
        CMD="$CMD --authgroup $VPN_AUTHGROUP"
    fi
    
    if [[ -n "$VPN_INTERFACE" ]]; then
        CMD="$CMD --interface $VPN_INTERFACE"
    fi
    
    if [[ -n "$VPN_SERVERCERT" ]]; then
        CMD="$CMD --servercert $VPN_SERVERCERT"
    fi
    
    if [[ "$NO_DTLS" == "true" ]]; then
        CMD="$CMD --no-dtls"
    fi
    
    if [[ -n "$VPN_LOG_FILE" ]]; then
        CMD="$CMD --log-file $VPN_LOG_FILE"
    fi
    
    if [[ -n "$EXTRA_ARGS" ]]; then
        CMD="$CMD --extra \"$EXTRA_ARGS\""
    fi
    
    echo -e "\e[33mExecuting: $CMD\e[39m"
    eval $CMD
    
    if [[ $? -eq 0 ]]; then
        echo -e "\e[32mVPN connected successfully!\e[39m"
    else
        echo -e "\e[31mFailed to connect to VPN\e[39m"
    fi
}

read_vpn_config() {
    read -p "Enter VPN Server (e.g., vpn.company.com): " VPN_SERVER
    read -p "Enter Username: " VPN_USERNAME
    read -p "Enter Auth Group (optional, press Enter to skip): " VPN_AUTHGROUP
    read -p "Enter Interface name (default: tun0): " VPN_INTERFACE
    VPN_INTERFACE=${VPN_INTERFACE:-tun0}
    read -p "Enter Server Certificate Pin (optional): " VPN_SERVERCERT
    read -p "Disable DTLS/UDP? (y/n, default: n): " disable_dtls
    if [[ "$disable_dtls" == "y" ]]; then
        NO_DTLS="true"
    else
        NO_DTLS="false"
    fi
    read -p "Enter log file path (optional): " VPN_LOG_FILE
    read -p "Enter extra arguments (optional): " EXTRA_ARGS
    
    read -p "Save this configuration? (y/n): " save_config
    if [[ "$save_config" == "y" ]]; then
        cat > "$CONFIG_FILE" << EOF
VPN_SERVER="$VPN_SERVER"
VPN_USERNAME="$VPN_USERNAME"
VPN_AUTHGROUP="$VPN_AUTHGROUP"
VPN_INTERFACE="$VPN_INTERFACE"
VPN_SERVERCERT="$VPN_SERVERCERT"
NO_DTLS="$NO_DTLS"
VPN_LOG_FILE="$VPN_LOG_FILE"
EXTRA_ARGS="$EXTRA_ARGS"
EOF
        echo -e "\e[32mConfiguration saved to $CONFIG_FILE\e[39m"
    fi
}

disconnect_vpn() {
    echo -e "\e[32m=== Disconnect from VPN ===\e[39m"
    
    sudo python3 "$PYTHON_SCRIPT" disconnect
    
    if [[ $? -eq 0 ]]; then
        echo -e "\e[32mVPN disconnected successfully!\e[39m"
    else
        echo -e "\e[31mFailed to disconnect or not connected\e[39m"
    fi
}

check_status() {
    echo -e "\e[32m=== VPN Connection Status ===\e[39m"
    
    sudo python3 "$PYTHON_SCRIPT" status
    
    echo ""
    echo -e "\e[33mInterface Status:\e[39m"
    ip addr show tun0 2>/dev/null || echo "No tun0 interface found"
}

edit_config() {
    echo -e "\e[32m=== Edit Configuration ===\e[39m"
    
    if [[ -f "$CONFIG_FILE" ]]; then
        read -p "Configuration file exists. Edit it? (y/n): " edit
        if [[ "$edit" == "y" ]]; then
            ${EDITOR:-nano} "$CONFIG_FILE"
            echo -e "\e[32mConfiguration updated\e[39m"
        fi
    else
        echo "No configuration file found. Creating new one..."
        read_vpn_config
    fi
}

view_config() {
    echo -e "\e[32m=== Current Configuration ===\e[39m"
    
    if [[ -f "$CONFIG_FILE" ]]; then
        cat "$CONFIG_FILE"
    else
        echo "No configuration file found at $CONFIG_FILE"
    fi
}

delete_config() {
    echo -e "\e[32m=== Delete Configuration ===\e[39m"
    
    if [[ -f "$CONFIG_FILE" ]]; then
        read -p "Are you sure you want to delete the configuration? (y/n): " confirm
        if [[ "$confirm" == "y" ]]; then
            rm "$CONFIG_FILE"
            echo -e "\e[32mConfiguration deleted\e[39m"
        fi
    else
        echo "No configuration file found"
    fi
}

install_dependencies() {
    echo -e "\e[32m=== Installing Dependencies ===\e[39m"
    
    echo "Checking for openconnect..."
    if ! command -v openconnect &> /dev/null; then
        echo -e "\e[33mInstalling openconnect...\e[39m"
        sudo apt-get update
        sudo apt-get install -y openconnect
    else
        echo -e "\e[32mopenconnect is already installed\e[39m"
    fi
    
    echo "Checking for Python 3..."
    if ! command -v python3 &> /dev/null; then
        echo -e "\e[33mInstalling Python 3...\e[39m"
        sudo apt-get install -y python3
    else
        echo -e "\e[32mPython 3 is already installed\e[39m"
    fi
    
    echo -e "\e[32mAll dependencies installed!\e[39m"
}

view_logs() {
    echo -e "\e[32m=== View VPN Logs ===\e[39m"
    
    if [[ -f "$CONFIG_FILE" ]]; then
        source "$CONFIG_FILE"
        if [[ -n "$VPN_LOG_FILE" && -f "$VPN_LOG_FILE" ]]; then
            echo "Showing last 50 lines of $VPN_LOG_FILE:"
            sudo tail -n 50 "$VPN_LOG_FILE"
        else
            echo "No log file configured or found"
        fi
    else
        read -p "Enter log file path: " log_path
        if [[ -f "$log_path" ]]; then
            sudo tail -n 50 "$log_path"
        else
            echo "Log file not found: $log_path"
        fi
    fi
}

# Check if script exists
if [[ ! -f "$PYTHON_SCRIPT" ]]; then
    echo -e "\e[31mError: openconnect_udp.py not found at $PYTHON_SCRIPT\e[39m"
    exit 1
fi

# Main menu
clear
echo '
 ██████╗ ██████╗ ███████╗███╗   ██╗     ██████╗ ██████╗ ███╗   ██╗███╗   ██╗███████╗ ██████╗████████╗
██╔═══██╗██╔══██╗██╔════╝████╗  ██║    ██╔════╝██╔═══██╗████╗  ██║████╗  ██║██╔════╝██╔════╝╚══██╔══╝
██║   ██║██████╔╝█████╗  ██╔██╗ ██║    ██║     ██║   ██║██╔██╗ ██║██╔██╗ ██║█████╗  ██║        ██║   
██║   ██║██╔═══╝ ██╔══╝  ██║╚██╗██║    ██║     ██║   ██║██║╚██╗██║██║╚██╗██║██╔══╝  ██║        ██║   
╚██████╔╝██║     ███████╗██║ ╚████║    ╚██████╗╚██████╔╝██║ ╚████║██║ ╚████║███████╗╚██████╗   ██║   
 ╚═════╝ ╚═╝     ╚══════╝╚═╝  ╚═══╝     ╚═════╝ ╚═════╝ ╚═╝  ╚═══╝╚═╝  ╚═══╝╚══════╝ ╚═════╝   ╚═╝   
                                                                                                        
        ██╗   ██╗██████╗ ███╗   ██╗     ██████╗██╗     ██╗███████╗███╗   ██╗████████╗                 
        ██║   ██║██╔══██╗████╗  ██║    ██╔════╝██║     ██║██╔════╝████╗  ██║╚══██╔══╝                 
        ██║   ██║██████╔╝██╔██╗ ██║    ██║     ██║     ██║█████╗  ██╔██╗ ██║   ██║                    
        ╚██╗ ██╔╝██╔═══╝ ██║╚██╗██║    ██║     ██║     ██║██╔══╝  ██║╚██╗██║   ██║                    
         ╚████╔╝ ██║     ██║ ╚████║    ╚██████╗███████╗██║███████╗██║ ╚████║   ██║                    
          ╚═══╝  ╚═╝     ╚═╝  ╚═══╝     ╚═════╝╚══════╝╚═╝╚══════╝╚═╝  ╚═══╝   ╚═╝                    
'

echo -e "\e[36mOpenConnect VPN Client Manager for Ubuntu Server\e[39m"
echo -e "\e[36mPython Script: $PYTHON_SCRIPT\e[39m"
echo ""

PS3='Please enter your choice: '
options=(
    "Connect to VPN" 
    "Disconnect from VPN" 
    "Check Status" 
    "Edit Configuration" 
    "View Configuration" 
    "Delete Configuration" 
    "Install Dependencies" 
    "View Logs" 
    "Quit"
)

select opt in "${options[@]}"
do
    case $opt in
        "Connect to VPN")
            connect_vpn
            break
            ;;
        "Disconnect from VPN")
            disconnect_vpn
            break
            ;;
        "Check Status")
            check_status
            break
            ;;
        "Edit Configuration")
            edit_config
            break
            ;;
        "View Configuration")
            view_config
            break
            ;;
        "Delete Configuration")
            delete_config
            break
            ;;
        "Install Dependencies")
            install_dependencies
            break
            ;;
        "View Logs")
            view_logs
            break
            ;;
        "Quit")
            echo "Goodbye!"
            break
            ;;
        *) 
            echo "Invalid option $REPLY"
            ;;
    esac
done

