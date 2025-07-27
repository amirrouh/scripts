#!/bin/bash

# SSH Manager - Enhanced SSH Management CLI with Passwordless Login
# Compatible with macOS and Linux
# Author: SSH Manager Tool
# Version: 2.0.0

set -euo pipefail

# Colors and formatting
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[1;37m'
readonly BOLD='\033[1m'
readonly NC='\033[0m' # No Color

# Configuration
readonly SSH_DIR="$HOME/.ssh"
readonly CONFIG_FILE="$SSH_DIR/config"
readonly BACKUP_DIR="$SSH_DIR/backups"
readonly SCRIPT_NAME="$(basename "$0")"

# Navigation state
CURRENT_MENU="main"
PREVIOUS_MENU=""

# Ensure SSH directory exists
ensure_ssh_dir() {
    if [[ ! -d "$SSH_DIR" ]]; then
        mkdir -p "$SSH_DIR"
        chmod 700 "$SSH_DIR"
    fi
}

# Utility functions
print_header() {
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${WHITE}${BOLD}                               SSH MANAGER                                   ${NC}${CYAN}║${NC}"
    echo -e "${CYAN}║${WHITE}                   Enhanced SSH Management with Passwordless Login            ${NC}${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo
}

print_breadcrumb() {
    local current="$1"
    echo -e "${BLUE}📍 Location: ${BOLD}$current${NC}\n"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1" >&2
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

print_section() {
    echo -e "\n${PURPLE}${BOLD}═══ $1 ═══${NC}\n"
}

confirm_action() {
    local message="$1"
    echo -e "${YELLOW}${message}${NC}"
    read -p "Do you want to continue? (y/N): " -n 1 -r
    echo
    [[ $REPLY =~ ^[Yy]$ ]]
}

show_navigation_options() {
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${WHITE}Navigation: ${NC}[${GREEN}Enter${NC}] Continue | [${YELLOW}b${NC}] Back | [${RED}q${NC}] Quit | [${BLUE}m${NC}] Main Menu"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════════════════════${NC}"
}

wait_for_navigation() {
    show_navigation_options
    while true; do
        read -p "Choice: " -n 1 -r nav_choice
        echo
        case "$nav_choice" in
            ""|$'\n')
                break
                ;;
            b|B)
                if [[ -n "$PREVIOUS_MENU" ]]; then
                    CURRENT_MENU="$PREVIOUS_MENU"
                    return 1
                else
                    CURRENT_MENU="main"
                    return 1
                fi
                ;;
            q|Q)
                echo -e "\n${GREEN}Thank you for using SSH Manager!${NC}"
                exit 0
                ;;
            m|M)
                CURRENT_MENU="main"
                return 1
                ;;
            *)
                print_error "Invalid option. Press Enter to continue, 'b' for back, 'q' to quit, or 'm' for main menu."
                ;;
        esac
    done
}

# SSH Key Management Functions
list_ssh_keys() {
    print_header
    print_breadcrumb "SSH Keys > List Keys"
    print_section "SSH Keys Overview"
    
    if [[ ! -d "$SSH_DIR" ]] || [[ -z "$(ls -A "$SSH_DIR"/*.pub 2>/dev/null || true)" ]]; then
        print_warning "No SSH keys found in $SSH_DIR"
        wait_for_navigation && return || return
    fi
    
    echo -e "${BOLD}Available SSH Keys:${NC}\n"
    
    local count=1
    for pub_key in "$SSH_DIR"/*.pub; do
        if [[ -f "$pub_key" ]]; then
            local key_name=$(basename "$pub_key" .pub)
            local private_key="$SSH_DIR/$key_name"
            
            echo -e "${WHITE}[$count]${NC} ${BOLD}$key_name${NC}"
            
            # Key type and size
            local key_info=$(ssh-keygen -l -f "$pub_key" 2>/dev/null || echo "Unknown format")
            echo -e "    ${BLUE}Info:${NC} $key_info"
            
            # Check if private key exists
            if [[ -f "$private_key" ]]; then
                print_success "    Private key: Present"
                
                # Check if key is password protected
                if ssh-keygen -y -f "$private_key" >/dev/null 2>&1; then
                    echo -e "    ${GREEN}Security:${NC} No passphrase"
                else
                    echo -e "    ${YELLOW}Security:${NC} Passphrase protected"
                fi
            else
                print_error "    Private key: Missing"
            fi
            
            # Check if key is loaded in agent
            if ssh-add -l 2>/dev/null | grep -q "$key_info" 2>/dev/null; then
                print_success "    Agent: Loaded"
            else
                echo -e "    ${YELLOW}Agent:${NC} Not loaded"
            fi
            
            echo
            ((count++))
        fi
    done
    
    wait_for_navigation && return || return
}

generate_ssh_key() {
    print_header
    print_breadcrumb "SSH Keys > Generate Key"
    print_section "Generate New SSH Key"
    
    echo -e "${BOLD}Key Generation Options:${NC}\n"
    echo "1. Ed25519 (Recommended - Modern, secure, fast)"
    echo "2. RSA 4096 (Traditional, widely compatible)"
    echo "3. ECDSA P-256 (Elliptic curve, good performance)"
    echo "4. RSA 2048 (Legacy compatibility)"
    echo
    
    read -p "Select key type (1-4): " key_choice
    
    case $key_choice in
        1)
            key_type="ed25519"
            key_params="-t ed25519"
            ;;
        2)
            key_type="rsa"
            key_params="-t rsa -b 4096"
            ;;
        3)
            key_type="ecdsa"
            key_params="-t ecdsa -b 256"
            ;;
        4)
            key_type="rsa"
            key_params="-t rsa -b 2048"
            ;;
        *)
            print_error "Invalid selection"
            wait_for_navigation && return || return
            ;;
    esac
    
    echo
    read -p "Enter a name for your key (e.g., 'work', 'personal', 'github'): " key_name
    
    if [[ -z "$key_name" ]]; then
        print_error "Key name cannot be empty"
        wait_for_navigation && return || return
    fi
    
    # Sanitize key name
    key_name=$(echo "$key_name" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9_-]/_/g')
    local key_path="$SSH_DIR/id_${key_type}_${key_name}"
    
    if [[ -f "$key_path" ]]; then
        print_error "Key '$key_name' already exists"
        wait_for_navigation && return || return
    fi
    
    echo
    read -p "Enter your email address: " email
    
    if [[ -z "$email" ]]; then
        print_error "Email address cannot be empty"
        wait_for_navigation && return || return
    fi
    
    echo
    print_info "Generating $key_type key: $key_name"
    
    if ssh-keygen $key_params -f "$key_path" -C "$email"; then
        print_success "SSH key generated successfully!"
        echo -e "\n${BOLD}Key Details:${NC}"
        echo -e "  Private key: $key_path"
        echo -e "  Public key:  $key_path.pub"
        echo -e "  Type:        $key_type"
        echo
        
        if confirm_action "Would you like to add this key to the SSH agent?"; then
            add_key_to_agent "$key_path"
        fi
        
        echo
        if confirm_action "Would you like to display the public key for copying?"; then
            echo -e "\n${BOLD}Public Key:${NC}"
            echo -e "${CYAN}$(cat "$key_path.pub")${NC}"
        fi
    else
        print_error "Failed to generate SSH key"
    fi
    
    wait_for_navigation && return || return
}

# SSH Key Copying and Passwordless Login Setup
copy_key_to_server() {
    print_header
    print_breadcrumb "Passwordless Login > Copy Key to Server"
    print_section "Copy SSH Key to Remote Server"
    
    # List available keys
    echo -e "${BOLD}Available SSH Keys:${NC}\n"
    local key_files=()
    local count=1
    
    for pub_key in "$SSH_DIR"/*.pub; do
        if [[ -f "$pub_key" ]]; then
            local key_name=$(basename "$pub_key" .pub)
            key_files+=("$SSH_DIR/$key_name")
            echo -e "  [$count] $key_name"
            ((count++))
        fi
    done
    
    if [[ ${#key_files[@]} -eq 0 ]]; then
        print_warning "No SSH keys found. Generate a key first."
        wait_for_navigation && return || return
    fi
    
    echo
    read -p "Select key to copy (1-$((count-1))): " key_choice
    
    if [[ ! "$key_choice" =~ ^[1-9][0-9]*$ ]] || [[ $key_choice -gt ${#key_files[@]} ]]; then
        print_error "Invalid selection"
        wait_for_navigation && return || return
    fi
    
    local selected_key="${key_files[$((key_choice-1))]}"
    local public_key="$selected_key.pub"
    
    echo
    echo -e "${BOLD}Server Connection Details:${NC}"
    
    # Check if we have configured hosts
    if [[ -f "$CONFIG_FILE" ]] && [[ -s "$CONFIG_FILE" ]]; then
        echo -e "\n${CYAN}Use existing host configuration?${NC}"
        local hosts=()
        local host_count=1
        
        while IFS= read -r line; do
            if [[ "$line" =~ ^[[:space:]]*Host[[:space:]]+(.+)$ ]]; then
                local host="${BASH_REMATCH[1]}"
                hosts+=("$host")
                echo -e "  [$host_count] $host"
                ((host_count++))
            fi
        done < "$CONFIG_FILE"
        
        echo -e "  [0] Enter custom connection details"
        echo
        read -p "Select option: " host_choice
        
        if [[ "$host_choice" =~ ^[1-9][0-9]*$ ]] && [[ $host_choice -le ${#hosts[@]} ]]; then
            local target="${hosts[$((host_choice-1))]}"
        elif [[ "$host_choice" == "0" ]]; then
            read -p "Username: " username
            read -p "Hostname/IP: " hostname
            read -p "Port (default: 22): " port
            port=${port:-22}
            target="$username@$hostname"
            if [[ "$port" != "22" ]]; then
                ssh_opts="-p $port"
            fi
        else
            print_error "Invalid selection"
            wait_for_navigation && return || return
        fi
    else
        read -p "Username: " username
        read -p "Hostname/IP: " hostname
        read -p "Port (default: 22): " port
        port=${port:-22}
        target="$username@$hostname"
        if [[ "$port" != "22" ]]; then
            ssh_opts="-p $port"
        fi
    fi
    
    echo
    print_info "Copying public key to $target"
    print_warning "You will be prompted for the server password"
    
    # Use ssh-copy-id if available, otherwise manual method
    if command -v ssh-copy-id >/dev/null 2>&1; then
        if ssh-copy-id ${ssh_opts:-} -i "$public_key" "$target"; then
            print_success "SSH key copied successfully!"
            echo
            print_info "Testing passwordless connection..."
            
            if ssh ${ssh_opts:-} -o BatchMode=yes -o ConnectTimeout=10 "$target" echo "Passwordless login works!" 2>/dev/null; then
                print_success "Passwordless login is working!"
            else
                print_warning "Key copied but passwordless login test failed. Please verify manually."
            fi
        else
            print_error "Failed to copy SSH key"
        fi
    else
        # Manual method for systems without ssh-copy-id
        print_info "ssh-copy-id not found, using manual method..."
        
        local pub_key_content=$(cat "$public_key")
        local remote_command="mkdir -p ~/.ssh && chmod 700 ~/.ssh && echo '$pub_key_content' >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"
        
        if ssh ${ssh_opts:-} "$target" "$remote_command"; then
            print_success "SSH key copied successfully!"
            echo
            print_info "Testing passwordless connection..."
            
            if ssh ${ssh_opts:-} -o BatchMode=yes -o ConnectTimeout=10 "$target" echo "Passwordless login works!" 2>/dev/null; then
                print_success "Passwordless login is working!"
            else
                print_warning "Key copied but passwordless login test failed. Please verify manually."
            fi
        else
            print_error "Failed to copy SSH key"
        fi
    fi
    
    wait_for_navigation && return || return
}

setup_passwordless_login() {
    print_header
    print_breadcrumb "Passwordless Login > Setup Wizard"
    print_section "Passwordless Login Setup Wizard"
    
    echo -e "${BOLD}Welcome to the Passwordless Login Setup!${NC}"
    echo -e "This wizard will help you set up SSH key authentication for a server.\n"
    
    echo -e "${BLUE}What this wizard will do:${NC}"
    echo -e "  1. Help you select or generate an SSH key"
    echo -e "  2. Copy your public key to the remote server"
    echo -e "  3. Test the passwordless connection"
    echo -e "  4. Optionally add the server to your SSH config"
    echo
    
    if ! confirm_action "Continue with passwordless login setup?"; then
        wait_for_navigation && return || return
    fi
    
    # Step 1: Check for existing keys or generate new one
    print_section "Step 1: SSH Key Selection"
    
    if [[ -z "$(ls -A "$SSH_DIR"/*.pub 2>/dev/null || true)" ]]; then
        print_warning "No SSH keys found."
        if confirm_action "Would you like to generate a new SSH key?"; then
            generate_ssh_key
        else
            print_error "SSH key required for passwordless login"
            wait_for_navigation && return || return
        fi
    else
        echo -e "${BOLD}Existing SSH keys found:${NC}\n"
        list_ssh_keys
        
        if confirm_action "Would you like to use an existing key or generate a new one?"; then
            echo "1. Use existing key"
            echo "2. Generate new key"
            read -p "Choice (1-2): " key_option
            
            if [[ "$key_option" == "2" ]]; then
                generate_ssh_key
            fi
        fi
    fi
    
    # Step 2: Copy key to server
    print_section "Step 2: Copy Key to Server"
    copy_key_to_server
    
    # Step 3: Add to SSH config (optional)
    print_section "Step 3: SSH Configuration (Optional)"
    if confirm_action "Would you like to add this server to your SSH config for easy access?"; then
        add_ssh_host
    fi
    
    print_success "Passwordless login setup complete!"
    print_info "You can now connect to your server without a password using: ssh hostname"
    
    wait_for_navigation && return || return
}

test_passwordless_login() {
    print_header
    print_breadcrumb "Passwordless Login > Test Connection"
    print_section "Test Passwordless SSH Connection"
    
    if [[ ! -f "$CONFIG_FILE" ]] || [[ ! -s "$CONFIG_FILE" ]]; then
        print_warning "No SSH config found. Testing direct connection."
        echo
        read -p "Enter username@hostname: " target
    else
        echo -e "${BOLD}Available configured hosts:${NC}\n"
        local hosts=()
        local count=1
        
        while IFS= read -r line; do
            if [[ "$line" =~ ^[[:space:]]*Host[[:space:]]+(.+)$ ]]; then
                local host="${BASH_REMATCH[1]}"
                hosts+=("$host")
                echo -e "  [$count] $host"
                ((count++))
            fi
        done < "$CONFIG_FILE"
        
        echo -e "  [0] Enter custom target"
        echo
        read -p "Select host to test: " selection
        
        if [[ "$selection" == "0" ]]; then
            read -p "Enter username@hostname: " target
        elif [[ "$selection" =~ ^[0-9]+$ ]] && [[ $selection -ge 1 ]] && [[ $selection -le ${#hosts[@]} ]]; then
            target="${hosts[$((selection-1))]}"
        else
            print_error "Invalid selection"
            wait_for_navigation && return || return
        fi
    fi
    
    if [[ -z "$target" ]]; then
        print_error "Target cannot be empty"
        wait_for_navigation && return || return
    fi
    
    print_info "Testing passwordless connection to: $target"
    echo
    
    # Test with BatchMode to ensure no password prompts
    if ssh -o BatchMode=yes -o ConnectTimeout=10 "$target" echo "Passwordless login successful!" 2>/dev/null; then
        print_success "✅ Passwordless login is working perfectly!"
        echo -e "   ${GREEN}You can connect without a password${NC}"
    else
        print_error "❌ Passwordless login failed"
        echo -e "\n${BLUE}Possible issues:${NC}"
        echo -e "  • SSH key not copied to server"
        echo -e "  • SSH key not loaded in agent"
        echo -e "  • Server SSH configuration issues"
        echo -e "  • Network connectivity problems"
        
        echo -e "\n${BLUE}Troubleshooting steps:${NC}"
        echo -e "  1. Copy your SSH key: Use option 'Copy Key to Server'"
        echo -e "  2. Check agent: Use 'SSH Agent > Show Status'"
        echo -e "  3. Test basic connection: Use 'Test SSH Connection'"
    fi
    
    wait_for_navigation && return || return
}

# Enhanced SSH Agent Management
show_agent_status() {
    print_header
    print_breadcrumb "SSH Agent > Status"
    print_section "SSH Agent Status"
    
    if ssh-add -l >/dev/null 2>&1; then
        print_success "SSH agent is running"
        echo -e "\n${BOLD}Loaded Keys:${NC}"
        ssh-add -l | while read -r line; do
            echo -e "  ${GREEN}•${NC} $line"
        done
        
        echo -e "\n${BOLD}Agent Information:${NC}"
        echo -e "  ${BLUE}SSH_AUTH_SOCK:${NC} ${SSH_AUTH_SOCK:-Not set}"
        echo -e "  ${BLUE}SSH_AGENT_PID:${NC} ${SSH_AGENT_PID:-Not set}"
    else
        local exit_code=$?
        case $exit_code in
            1)
                print_warning "SSH agent is running but no keys are loaded"
                echo -e "\n${BLUE}To add keys:${NC}"
                echo -e "  • Use 'Add Key to Agent' or 'Add All Keys'"
                ;;
            2)
                print_error "SSH agent is not running"
                echo -e "\n${BLUE}To start the SSH agent:${NC}"
                echo -e "  eval \"\$(ssh-agent -s)\""
                echo -e "\n${BLUE}Or add to your shell profile:${NC}"
                echo -e "  echo 'eval \"\$(ssh-agent -s)\"' >> ~/.bashrc"
                ;;
            *)
                print_error "Unable to communicate with SSH agent"
                ;;
        esac
    fi
    
    wait_for_navigation && return || return
}

add_key_to_agent() {
    local key_path="$1"
    
    if [[ ! -f "$key_path" ]]; then
        print_error "Key file not found: $key_path"
        return 1
    fi
    
    print_info "Adding key to SSH agent: $(basename "$key_path")"
    
    if ssh-add "$key_path"; then
        print_success "Key added to SSH agent successfully"
    else
        print_error "Failed to add key to SSH agent"
        return 1
    fi
}

# Enhanced Connection Management with better navigation
show_ssh_config() {
    print_header
    print_breadcrumb "Connections > SSH Config"
    print_section "SSH Configuration"
    
    if [[ ! -f "$CONFIG_FILE" ]]; then
        print_warning "SSH config file not found: $CONFIG_FILE"
        echo -e "\n${BLUE}To create a basic config file:${NC}"
        echo -e "  touch $CONFIG_FILE"
        echo -e "  chmod 600 $CONFIG_FILE"
        wait_for_navigation && return || return
    fi
    
    echo -e "${BOLD}SSH Config File: $CONFIG_FILE${NC}\n"
    
    if [[ -s "$CONFIG_FILE" ]]; then
        # Parse and display hosts
        local current_host=""
        local host_count=0
        
        while IFS= read -r line; do
            if [[ "$line" =~ ^[[:space:]]*Host[[:space:]]+(.+)$ ]]; then
                if [[ -n "$current_host" ]]; then
                    echo
                fi
                current_host="${BASH_REMATCH[1]}"
                ((host_count++))
                echo -e "${GREEN}[$host_count]${NC} ${BOLD}$current_host${NC}"
            elif [[ "$line" =~ ^[[:space:]]*([A-Za-z]+)[[:space:]]+(.+)$ ]] && [[ -n "$current_host" ]]; then
                local key="${BASH_REMATCH[1]}"
                local value="${BASH_REMATCH[2]}"
                echo -e "    ${BLUE}$key:${NC} $value"
            fi
        done < "$CONFIG_FILE"
        
        if [[ $host_count -eq 0 ]]; then
            print_warning "No host configurations found in SSH config"
        fi
    else
        print_warning "SSH config file is empty"
    fi
    
    wait_for_navigation && return || return
}

# Menu Systems with improved navigation
show_main_menu() {
    print_header
    print_breadcrumb "Main Menu"
    
    echo -e "${BOLD}Main Menu${NC}\n"
    
    echo -e "${CYAN}🔑 SSH Keys:${NC}"
    echo -e "  1. List SSH keys"
    echo -e "  2. Generate new SSH key"
    echo -e "  3. Delete SSH key"
    echo -e "  4. Change key passphrase"
    
    echo -e "\n${CYAN}🔐 Passwordless Login:${NC}"
    echo -e "  5. Setup passwordless login wizard"
    echo -e "  6. Copy key to server"
    echo -e "  7. Test passwordless connection"
    
    echo -e "\n${CYAN}🤖 SSH Agent:${NC}"
    echo -e "  8. Show agent status"
    echo -e "  9. Add key to agent"
    echo -e " 10. Add all keys to agent"
    echo -e " 11. Remove key from agent"
    
    echo -e "\n${CYAN}🌐 Connections:${NC}"
    echo -e " 12. Show SSH config"
    echo -e " 13. Add SSH host"
    echo -e " 14. Remove SSH host"
    echo -e " 15. Test SSH connection"
    
    echo -e "\n${CYAN}🔧 Maintenance:${NC}"
    echo -e " 16. Backup SSH config"
    echo -e " 17. Restore SSH config"
    echo -e " 18. Security check"
    echo -e " 19. Fix permissions"
    
    echo -e "\n${CYAN}❓ Help & Info:${NC}"
    echo -e " 20. Help"
    echo -e " 21. Exit"
    
    echo
}

show_passwordless_menu() {
    print_header
    print_breadcrumb "Passwordless Login Menu"
    
    echo -e "${BOLD}Passwordless Login Management${NC}\n"
    
    echo -e "${GREEN}Quick Actions:${NC}"
    echo -e "  1. 🚀 Setup passwordless login (wizard)"
    echo -e "  2. 📤 Copy SSH key to server"
    echo -e "  3. 🧪 Test passwordless connection"
    
    echo -e "\n${BLUE}Advanced:${NC}"
    echo -e "  4. 📋 List all SSH keys"
    echo -e "  5. ⚡ Generate new SSH key"
    echo -e "  6. 🔧 Add SSH host configuration"
    
    echo -e "\n${YELLOW}Navigation:${NC}"
    echo -e "  7. 🏠 Back to main menu"
    echo -e "  8. ❌ Exit"
    
    echo
}

# Complete SSH Key Management Functions
delete_ssh_key() {
    print_header
    print_breadcrumb "SSH Keys > Delete Key"
    print_section "Delete SSH Key"
    
    # List existing keys first
    if [[ -z "$(ls -A "$SSH_DIR"/*.pub 2>/dev/null || true)" ]]; then
        print_warning "No SSH keys found to delete"
        wait_for_navigation && return || return
    fi
    
    echo -e "${BOLD}Available SSH Keys:${NC}\n"
    local key_files=()
    local count=1
    
    for pub_key in "$SSH_DIR"/*.pub; do
        if [[ -f "$pub_key" ]]; then
            local key_name=$(basename "$pub_key" .pub)
            key_files+=("$key_name")
            echo -e "  [$count] $key_name"
            ((count++))
        fi
    done
    
    echo
    read -p "Select key to delete (1-$((count-1))): " key_choice
    
    if [[ ! "$key_choice" =~ ^[1-9][0-9]*$ ]] || [[ $key_choice -gt ${#key_files[@]} ]]; then
        print_error "Invalid selection"
        wait_for_navigation && return || return
    fi
    
    local key_name="${key_files[$((key_choice-1))]}"
    local private_key="$SSH_DIR/$key_name"
    local public_key="$SSH_DIR/$key_name.pub"
    
    echo -e "\n${RED}${BOLD}WARNING: This action cannot be undone!${NC}"
    echo -e "Files to be deleted:"
    [[ -f "$private_key" ]] && echo -e "  - $private_key"
    [[ -f "$public_key" ]] && echo -e "  - $public_key"
    
    if confirm_action "\nAre you sure you want to delete key '$key_name'?"; then
        # Remove from agent if loaded
        ssh-add -d "$private_key" 2>/dev/null || true
        
        # Delete files
        [[ -f "$private_key" ]] && rm "$private_key"
        [[ -f "$public_key" ]] && rm "$public_key"
        
        print_success "SSH key '$key_name' deleted successfully"
        
        # Remove from SSH config if present
        if [[ -f "$CONFIG_FILE" ]] && grep -q "$private_key" "$CONFIG_FILE"; then
            print_info "Removing references from SSH config..."
            sed -i.bak "/IdentityFile.*$key_name/d" "$CONFIG_FILE"
        fi
    fi
    
    wait_for_navigation && return || return
}

change_key_passphrase() {
    print_header
    print_breadcrumb "SSH Keys > Change Passphrase"
    print_section "Change Key Passphrase"
    
    if [[ -z "$(ls -A "$SSH_DIR"/*.pub 2>/dev/null || true)" ]]; then
        print_warning "No SSH keys found"
        wait_for_navigation && return || return
    fi
    
    echo -e "${BOLD}Available SSH Keys:${NC}\n"
    local key_files=()
    local count=1
    
    for pub_key in "$SSH_DIR"/*.pub; do
        if [[ -f "$pub_key" ]]; then
            local key_name=$(basename "$pub_key" .pub)
            key_files+=("$key_name")
            echo -e "  [$count] $key_name"
            ((count++))
        fi
    done
    
    echo
    read -p "Select key to change passphrase (1-$((count-1))): " key_choice
    
    if [[ ! "$key_choice" =~ ^[1-9][0-9]*$ ]] || [[ $key_choice -gt ${#key_files[@]} ]]; then
        print_error "Invalid selection"
        wait_for_navigation && return || return
    fi
    
    local key_name="${key_files[$((key_choice-1))]}"
    local private_key="$SSH_DIR/$key_name"
    
    if [[ ! -f "$private_key" ]]; then
        print_error "Private key '$key_name' not found"
        wait_for_navigation && return || return
    fi
    
    print_info "Changing passphrase for key: $key_name"
    
    if ssh-keygen -p -f "$private_key"; then
        print_success "Passphrase changed successfully"
        
        if confirm_action "Would you like to reload this key in the SSH agent?"; then
            ssh-add -d "$private_key" 2>/dev/null || true
            add_key_to_agent "$private_key"
        fi
    else
        print_error "Failed to change passphrase"
    fi
    
    wait_for_navigation && return || return
}

add_all_keys_to_agent() {
    print_header
    print_breadcrumb "SSH Agent > Add All Keys"
    print_section "Add All Keys to Agent"
    
    if [[ ! -d "$SSH_DIR" ]]; then
        print_error "SSH directory not found"
        wait_for_navigation && return || return
    fi
    
    local added_count=0
    
    for private_key in "$SSH_DIR"/id_*; do
        if [[ -f "$private_key" ]] && [[ ! "$private_key" == *.pub ]]; then
            echo -e "\nProcessing: $(basename "$private_key")"
            if add_key_to_agent "$private_key"; then
                ((added_count++))
            fi
        fi
    done
    
    if [[ $added_count -eq 0 ]]; then
        print_warning "No keys were added to the agent"
    else
        print_success "Added $added_count key(s) to the SSH agent"
    fi
    
    wait_for_navigation && return || return
}

remove_key_from_agent() {
    print_header
    print_breadcrumb "SSH Agent > Remove Key"
    print_section "Remove Key from Agent"
    
    if ! ssh-add -l >/dev/null 2>&1; then
        print_error "No SSH agent running or no keys loaded"
        wait_for_navigation && return || return
    fi
    
    echo -e "${BOLD}Currently loaded keys:${NC}\n"
    ssh-add -l | nl -w2 -s'. '
    
    echo
    read -p "Enter the number of the key to remove (or 'all' for all keys): " selection
    
    if [[ "$selection" == "all" ]]; then
        if confirm_action "Remove all keys from SSH agent?"; then
            ssh-add -D
            print_success "All keys removed from SSH agent"
        fi
    elif [[ "$selection" =~ ^[0-9]+$ ]]; then
        local key_info=$(ssh-add -l | sed -n "${selection}p")
        if [[ -n "$key_info" ]]; then
            local key_file=$(echo "$key_info" | awk '{print $NF}')
            if ssh-add -d "$key_file" 2>/dev/null; then
                print_success "Key removed from SSH agent"
            else
                print_error "Failed to remove key from SSH agent"
            fi
        else
            print_error "Invalid selection"
        fi
    else
        print_error "Invalid selection"
    fi
    
    wait_for_navigation && return || return
}

add_ssh_host() {
    print_header
    print_breadcrumb "Connections > Add Host"
    print_section "Add SSH Host Configuration"
    
    read -p "Host alias (e.g., 'myserver', 'production'): " host_alias
    if [[ -z "$host_alias" ]]; then
        print_error "Host alias cannot be empty"
        wait_for_navigation && return || return
    fi
    
    read -p "Hostname or IP address: " hostname
    if [[ -z "$hostname" ]]; then
        print_error "Hostname cannot be empty"
        wait_for_navigation && return || return
    fi
    
    read -p "Username: " username
    if [[ -z "$username" ]]; then
        print_error "Username cannot be empty"
        wait_for_navigation && return || return
    fi
    
    read -p "Port (default: 22): " port
    port=${port:-22}
    
    # Show available keys
    echo -e "\n${BOLD}Available SSH keys:${NC}"
    local key_files=()
    local count=1
    
    for pub_key in "$SSH_DIR"/*.pub; do
        if [[ -f "$pub_key" ]]; then
            local key_name=$(basename "$pub_key" .pub)
            key_files+=("$SSH_DIR/$key_name")
            echo -e "  [$count] $key_name"
            ((count++))
        fi
    done
    
    if [[ ${#key_files[@]} -eq 0 ]]; then
        print_warning "No SSH keys found. Generate a key first."
        wait_for_navigation && return || return
    fi
    
    echo -e "  [0] Skip (use default key)"
    echo
    read -p "Select key to use (0-$((count-1))): " key_choice
    
    local identity_file=""
    if [[ "$key_choice" =~ ^[1-9][0-9]*$ ]] && [[ $key_choice -le ${#key_files[@]} ]]; then
        identity_file="${key_files[$((key_choice-1))]}"
    fi
    
    # Create config entry
    ensure_ssh_dir
    
    if [[ ! -f "$CONFIG_FILE" ]]; then
        touch "$CONFIG_FILE"
        chmod 600 "$CONFIG_FILE"
    fi
    
    # Check if host already exists
    if grep -q "^Host $host_alias$" "$CONFIG_FILE" 2>/dev/null; then
        print_error "Host '$host_alias' already exists in SSH config"
        wait_for_navigation && return || return
    fi
    
    # Append new host configuration
    {
        echo
        echo "Host $host_alias"
        echo "    HostName $hostname"
        echo "    User $username"
        echo "    Port $port"
        [[ -n "$identity_file" ]] && echo "    IdentityFile $identity_file"
        echo "    IdentitiesOnly yes"
    } >> "$CONFIG_FILE"
    
    print_success "Host '$host_alias' added to SSH config"
    echo -e "\n${BOLD}You can now connect using:${NC}"
    echo -e "  ${CYAN}ssh $host_alias${NC}"
    
    wait_for_navigation && return || return
}

remove_ssh_host() {
    print_header
    print_breadcrumb "Connections > Remove Host"
    print_section "Remove SSH Host Configuration"
    
    if [[ ! -f "$CONFIG_FILE" ]] || [[ ! -s "$CONFIG_FILE" ]]; then
        print_warning "No SSH config file found or file is empty"
        wait_for_navigation && return || return
    fi
    
    # List existing hosts
    echo -e "${BOLD}Current SSH hosts:${NC}\n"
    local hosts=()
    local count=1
    
    while IFS= read -r line; do
        if [[ "$line" =~ ^[[:space:]]*Host[[:space:]]+(.+)$ ]]; then
            local host="${BASH_REMATCH[1]}"
            hosts+=("$host")
            echo -e "  [$count] $host"
            ((count++))
        fi
    done < "$CONFIG_FILE"
    
    if [[ ${#hosts[@]} -eq 0 ]]; then
        print_warning "No host configurations found"
        wait_for_navigation && return || return
    fi
    
    echo
    read -p "Enter the number of the host to remove: " selection
    
    if [[ "$selection" =~ ^[0-9]+$ ]] && [[ $selection -ge 1 ]] && [[ $selection -le ${#hosts[@]} ]]; then
        local host_to_remove="${hosts[$((selection-1))]}"
        
        if confirm_action "Remove host '$host_to_remove' from SSH config?"; then
            # Create backup
            cp "$CONFIG_FILE" "$CONFIG_FILE.bak"
            
            # Remove host block
            awk -v host="$host_to_remove" '
                /^Host / { 
                    in_host_block = ($2 == host) 
                    if (!in_host_block) print
                    next
                }
                /^Host / || /^$/ { 
                    in_host_block = 0 
                    print
                    next
                }
                !in_host_block { print }
            ' "$CONFIG_FILE.bak" > "$CONFIG_FILE"
            
            print_success "Host '$host_to_remove' removed from SSH config"
        fi
    else
        print_error "Invalid selection"
    fi
    
    wait_for_navigation && return || return
}

test_ssh_connection() {
    print_header
    print_breadcrumb "Connections > Test Connection"
    print_section "Test SSH Connection"
    
    if [[ ! -f "$CONFIG_FILE" ]] || [[ ! -s "$CONFIG_FILE" ]]; then
        print_warning "No SSH config found. You can still test direct connections."
        echo
        read -p "Enter hostname or IP address: " target
    else
        echo -e "${BOLD}Available hosts:${NC}\n"
        local hosts=()
        local count=1
        
        while IFS= read -r line; do
            if [[ "$line" =~ ^[[:space:]]*Host[[:space:]]+(.+)$ ]]; then
                local host="${BASH_REMATCH[1]}"
                hosts+=("$host")
                echo -e "  [$count] $host"
                ((count++))
            fi
        done < "$CONFIG_FILE"
        
        echo -e "  [0] Enter custom hostname"
        echo
        read -p "Select host to test: " selection
        
        if [[ "$selection" == "0" ]]; then
            read -p "Enter hostname or IP address: " target
        elif [[ "$selection" =~ ^[0-9]+$ ]] && [[ $selection -ge 1 ]] && [[ $selection -le ${#hosts[@]} ]]; then
            target="${hosts[$((selection-1))]}"
        else
            print_error "Invalid selection"
            wait_for_navigation && return || return
        fi
    fi
    
    if [[ -z "$target" ]]; then
        print_error "Target cannot be empty"
        wait_for_navigation && return || return
    fi
    
    print_info "Testing connection to: $target"
    echo
    
    if ssh -o ConnectTimeout=10 -o BatchMode=yes "$target" echo "Connection successful" 2>/dev/null; then
        print_success "SSH connection to '$target' is working!"
    else
        print_error "SSH connection to '$target' failed"
        echo -e "\n${BLUE}Troubleshooting tips:${NC}"
        echo -e "  • Check if the host is reachable: ping $target"
        echo -e "  • Verify SSH service is running on the target"
        echo -e "  • Check firewall settings"
        echo -e "  • Ensure your SSH key is authorized on the target"
    fi
    
    wait_for_navigation && return || return
}

# Backup and Restore Functions
backup_ssh_config() {
    print_header
    print_breadcrumb "Maintenance > Backup Config"
    print_section "Backup SSH Configuration"
    
    ensure_ssh_dir
    
    if [[ ! -d "$BACKUP_DIR" ]]; then
        mkdir -p "$BACKUP_DIR"
        chmod 700 "$BACKUP_DIR"
    fi
    
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local backup_file="$BACKUP_DIR/ssh_backup_$timestamp.tar.gz"
    
    print_info "Creating backup of SSH configuration..."
    
    cd "$SSH_DIR"
    if tar -czf "$backup_file" --exclude="backups" . 2>/dev/null; then
        print_success "Backup created: $backup_file"
        
        # Show backup size
        local size=$(du -h "$backup_file" | cut -f1)
        echo -e "  ${BLUE}Size:${NC} $size"
        
        # Clean up old backups (keep last 5)
        local backup_count=$(ls -1 "$BACKUP_DIR"/ssh_backup_*.tar.gz 2>/dev/null | wc -l)
        if [[ $backup_count -gt 5 ]]; then
            print_info "Cleaning up old backups (keeping last 5)..."
            ls -1t "$BACKUP_DIR"/ssh_backup_*.tar.gz | tail -n +6 | xargs rm -f
        fi
    else
        print_error "Failed to create backup"
    fi
    
    wait_for_navigation && return || return
}

restore_ssh_config() {
    print_header
    print_breadcrumb "Maintenance > Restore Config"
    print_section "Restore SSH Configuration"
    
    if [[ ! -d "$BACKUP_DIR" ]] || [[ -z "$(ls -A "$BACKUP_DIR"/*.tar.gz 2>/dev/null || true)" ]]; then
        print_warning "No backups found in $BACKUP_DIR"
        wait_for_navigation && return || return
    fi
    
    echo -e "${BOLD}Available backups:${NC}\n"
    local backups=()
    local count=1
    
    for backup in "$BACKUP_DIR"/*.tar.gz; do
        if [[ -f "$backup" ]]; then
            local filename=$(basename "$backup")
            local size=$(du -h "$backup" | cut -f1)
            local date=$(echo "$filename" | sed 's/ssh_backup_\([0-9]\{8\}_[0-9]\{6\}\).*/\1/' | sed 's/_/ /')
            
            backups+=("$backup")
            echo -e "  [$count] $filename"
            echo -e "       Date: $date, Size: $size"
            ((count++))
        fi
    done
    
    echo
    read -p "Select backup to restore: " selection
    
    if [[ "$selection" =~ ^[0-9]+$ ]] && [[ $selection -ge 1 ]] && [[ $selection -le ${#backups[@]} ]]; then
        local backup_file="${backups[$((selection-1))]}"
        
        echo -e "\n${RED}${BOLD}WARNING: This will overwrite your current SSH configuration!${NC}"
        
        if confirm_action "Are you sure you want to restore from this backup?"; then
            # Create current backup before restore
            print_info "Creating backup of current configuration..."
            backup_ssh_config
            
            # Restore from backup
            print_info "Restoring SSH configuration..."
            cd "$SSH_DIR"
            
            if tar -xzf "$backup_file"; then
                print_success "SSH configuration restored successfully"
                echo -e "\n${BLUE}You may need to restart your SSH agent and reload keys.${NC}"
            else
                print_error "Failed to restore SSH configuration"
            fi
        fi
    else
        print_error "Invalid selection"
    fi
    
    wait_for_navigation && return || return
}

# Security Functions
check_ssh_security() {
    print_header
    print_breadcrumb "Maintenance > Security Check"
    print_section "SSH Security Check"
    
    local issues=0
    
    # Check SSH directory permissions
    if [[ -d "$SSH_DIR" ]]; then
        local ssh_perms=$(stat -c "%a" "$SSH_DIR" 2>/dev/null || stat -f "%A" "$SSH_DIR" 2>/dev/null)
        if [[ "$ssh_perms" != "700" ]]; then
            print_warning "SSH directory permissions are too open: $ssh_perms (should be 700)"
            ((issues++))
        else
            print_success "SSH directory permissions are correct"
        fi
    fi
    
    # Check private key permissions
    for private_key in "$SSH_DIR"/id_*; do
        if [[ -f "$private_key" ]] && [[ ! "$private_key" == *.pub ]]; then
            local key_perms=$(stat -c "%a" "$private_key" 2>/dev/null || stat -f "%A" "$private_key" 2>/dev/null)
            if [[ "$key_perms" != "600" ]]; then
                print_warning "Private key $(basename "$private_key") has incorrect permissions: $key_perms (should be 600)"
                ((issues++))
            fi
        fi
    done
    
    # Check config file permissions
    if [[ -f "$CONFIG_FILE" ]]; then
        local config_perms=$(stat -c "%a" "$CONFIG_FILE" 2>/dev/null || stat -f "%A" "$CONFIG_FILE" 2>/dev/null)
        if [[ "$config_perms" != "600" ]]; then
            print_warning "SSH config file has incorrect permissions: $config_perms (should be 600)"
            ((issues++))
        else
            print_success "SSH config file permissions are correct"
        fi
    fi
    
    # Check for weak keys
    print_info "Checking key strength..."
    for pub_key in "$SSH_DIR"/*.pub; do
        if [[ -f "$pub_key" ]]; then
            local key_info=$(ssh-keygen -l -f "$pub_key" 2>/dev/null || continue)
            local key_bits=$(echo "$key_info" | awk '{print $1}')
            local key_type=$(echo "$key_info" | awk '{print $4}' | tr -d '()')
            
            case "$key_type" in
                RSA)
                    if [[ $key_bits -lt 2048 ]]; then
                        print_warning "Weak RSA key detected: $(basename "$pub_key") ($key_bits bits)"
                        ((issues++))
                    fi
                    ;;
                DSA)
                    print_warning "DSA key detected: $(basename "$pub_key") (DSA is deprecated)"
                    ((issues++))
                    ;;
            esac
        fi
    done
    
    echo
    if [[ $issues -eq 0 ]]; then
        print_success "No security issues found!"
    else
        print_warning "Found $issues security issue(s). Consider running the fix permissions option."
    fi
    
    wait_for_navigation && return || return
}

fix_ssh_permissions() {
    print_header
    print_breadcrumb "Maintenance > Fix Permissions"
    print_section "Fix SSH Permissions"
    
    if confirm_action "This will fix permissions for SSH directory, keys, and config files."; then
        local fixed=0
        
        # Fix SSH directory
        if [[ -d "$SSH_DIR" ]]; then
            chmod 700 "$SSH_DIR"
            print_success "Fixed SSH directory permissions"
            ((fixed++))
        fi
        
        # Fix private keys
        for private_key in "$SSH_DIR"/id_*; do
            if [[ -f "$private_key" ]] && [[ ! "$private_key" == *.pub ]]; then
                chmod 600 "$private_key"
                print_success "Fixed permissions for $(basename "$private_key")"
                ((fixed++))
            fi
        done
        
        # Fix public keys
        for pub_key in "$SSH_DIR"/*.pub; do
            if [[ -f "$pub_key" ]]; then
                chmod 644 "$pub_key"
                ((fixed++))
            fi
        done
        
        # Fix config file
        if [[ -f "$CONFIG_FILE" ]]; then
            chmod 600 "$CONFIG_FILE"
            print_success "Fixed SSH config permissions"
            ((fixed++))
        fi
        
        # Fix known_hosts
        if [[ -f "$SSH_DIR/known_hosts" ]]; then
            chmod 644 "$SSH_DIR/known_hosts"
            ((fixed++))
        fi
        
        print_success "Fixed permissions for $fixed file(s)"
    fi
    
    wait_for_navigation && return || return
}

# Main execution flow with enhanced navigation
main() {
    # Handle command line arguments
    case "${1:-}" in
        -h|--help)
            show_help
            exit 0
            ;;
        -v|--version)
            show_version
            exit 0
            ;;
        --quick-setup)
            quick_setup_wizard
            exit 0
            ;;
        "")
            # Interactive mode
            ;;
        *)
            print_error "Unknown option: $1"
            echo "Use --help for usage information."
            exit 1
            ;;
    esac
    
    # Ensure SSH directory exists
    ensure_ssh_dir
    
    # Main interactive loop with navigation
    while true; do
        case "$CURRENT_MENU" in
            "main")
                show_main_menu
                read -p "Enter your choice (1-21): " choice
                
                case $choice in
                    1) 
                        PREVIOUS_MENU="main"
                        list_ssh_keys
                        ;;
                    2) 
                        PREVIOUS_MENU="main"
                        generate_ssh_key
                        ;;
                    3) 
                        PREVIOUS_MENU="main"
                        delete_ssh_key
                        ;;
                    4) 
                        PREVIOUS_MENU="main"
                        change_key_passphrase
                        ;;
                    5) 
                        PREVIOUS_MENU="main"
                        setup_passwordless_login
                        ;;
                    6) 
                        PREVIOUS_MENU="main"
                        copy_key_to_server
                        ;;
                    7) 
                        PREVIOUS_MENU="main"
                        test_passwordless_login
                        ;;
                    8) 
                        PREVIOUS_MENU="main"
                        show_agent_status
                        ;;
                    9)
                        PREVIOUS_MENU="main"
                        # Add single key to agent
                        if [[ -z "$(ls -A "$SSH_DIR"/*.pub 2>/dev/null || true)" ]]; then
                            print_warning "No SSH keys found"
                            sleep 2
                        else
                            echo -e "${BOLD}Available SSH Keys:${NC}\n"
                            local key_files=()
                            local count=1
                            
                            for pub_key in "$SSH_DIR"/*.pub; do
                                if [[ -f "$pub_key" ]]; then
                                    local key_name=$(basename "$pub_key" .pub)
                                    key_files+=("$key_name")
                                    echo -e "  [$count] $key_name"
                                    ((count++))
                                fi
                            done
                            
                            echo
                            read -p "Select key to add to agent (1-$((count-1))): " key_choice
                            
                            if [[ "$key_choice" =~ ^[1-9][0-9]*$ ]] && [[ $key_choice -le ${#key_files[@]} ]]; then
                                local selected_key="${key_files[$((key_choice-1))]}"
                                add_key_to_agent "$SSH_DIR/$selected_key"
                            else
                                print_error "Invalid selection"
                            fi
                            sleep 2
                        fi
                        ;;
                    10) 
                        PREVIOUS_MENU="main"
                        add_all_keys_to_agent
                        ;;
                    11) 
                        PREVIOUS_MENU="main"
                        remove_key_from_agent
                        ;;
                    12) 
                        PREVIOUS_MENU="main"
                        show_ssh_config
                        ;;
                    13) 
                        PREVIOUS_MENU="main"
                        add_ssh_host
                        ;;
                    14) 
                        PREVIOUS_MENU="main"
                        remove_ssh_host
                        ;;
                    15) 
                        PREVIOUS_MENU="main"
                        test_ssh_connection
                        ;;
                    16) 
                        PREVIOUS_MENU="main"
                        backup_ssh_config
                        ;;
                    17) 
                        PREVIOUS_MENU="main"
                        restore_ssh_config
                        ;;
                    18) 
                        PREVIOUS_MENU="main"
                        check_ssh_security
                        ;;
                    19) 
                        PREVIOUS_MENU="main"
                        fix_ssh_permissions
                        ;;
                    20) 
                        PREVIOUS_MENU="main"
                        show_help
                        ;;
                    21) 
                        echo -e "\n${GREEN}Thank you for using SSH Manager!${NC}"
                        exit 0
                        ;;
                    *)
                        print_error "Invalid choice. Please enter a number between 1 and 21."
                        sleep 2
                        ;;
                esac
                ;;
            "passwordless")
                show_passwordless_menu
                read -p "Enter your choice (1-8): " choice
                
                case $choice in
                    1) setup_passwordless_login ;;
                    2) copy_key_to_server ;;
                    3) test_passwordless_login ;;
                    7) CURRENT_MENU="main" ;;
                    8) 
                        echo -e "\n${GREEN}Thank you for using SSH Manager!${NC}"
                        exit 0
                        ;;
                    *)
                        print_error "Invalid choice. Please enter a number between 1 and 8."
                        sleep 2
                        ;;
                esac
                ;;
        esac
    done
}

# Help and version functions (simplified for space)
show_help() {
    print_header
    echo -e "${BOLD}SSH Manager v2.0 - Enhanced SSH Management Tool${NC}\n"
    echo -e "${PURPLE}${BOLD}NEW FEATURES:${NC}"
    echo -e "  • Passwordless login setup wizard"
    echo -e "  • SSH key copying to servers"
    echo -e "  • Enhanced page-by-page navigation"
    echo -e "  • Connection testing and troubleshooting"
    echo
    wait_for_navigation && return || return
}

show_version() {
    print_header
    echo -e "${BOLD}SSH Manager${NC}"
    echo -e "Version: 2.0.0"
    echo -e "Enhanced with passwordless login support"
    echo -e "Compatible: macOS and Linux"
    echo
    wait_for_navigation && return || return
}

# Quick setup wizard (enhanced)
quick_setup_wizard() {
    print_header
    print_section "Quick SSH Setup Wizard"
    
    echo -e "${BOLD}Welcome to SSH Manager v2.0!${NC}"
    echo -e "This wizard will help you set up SSH with passwordless login.\n"
    
    if confirm_action "Start the enhanced setup wizard?"; then
        setup_passwordless_login
    fi
}

# Run main function with all arguments
main "$@"