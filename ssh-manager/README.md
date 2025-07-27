# SSH Manager v2.0 - Enhanced SSH Management Tool

A comprehensive, user-friendly CLI tool for managing SSH keys, passwordless logins, and SSH configurations on macOS and Linux.

## 🚀 Features

### 🔑 SSH Key Management
- **Generate SSH keys** with modern algorithms (Ed25519, RSA, ECDSA)
- **List all SSH keys** with detailed information
- **Delete SSH keys** safely with confirmation
- **Change key passphrases** easily

### 🔐 Passwordless Login (NEW!)
- **Setup wizard** for passwordless SSH authentication
- **Copy SSH keys to servers** (ssh-copy-id equivalent)
- **Test passwordless connections** with detailed troubleshooting
- **Works with existing hosts** from SSH config

### 🤖 SSH Agent Management
- **View agent status** and loaded keys
- **Add/remove keys** to/from SSH agent
- **Bulk operations** for managing multiple keys

### 🌐 Connection Management
- **Manage SSH config** with easy host addition/removal
- **Test SSH connections** with troubleshooting tips
- **Associate specific keys** with hosts

### 🔧 Maintenance & Security
- **Backup/restore** SSH configurations
- **Security checks** for permissions and weak keys
- **Automatic permission fixes**
- **Cross-platform compatibility**

## 📦 Installation

1. **Download the script:**
   ```bash
   curl -o ssh-manager.sh https://raw.githubusercontent.com/yourusername/ssh-manager/main/ssh-manager.sh
   chmod +x ssh-manager.sh
   ```

2. **Make it globally accessible (optional):**
   ```bash
   sudo mv ssh-manager.sh /usr/local/bin/ssh-manager
   ```

## 🖥️ Usage

### Basic Usage
```bash
./ssh-manager.sh              # Interactive menu
./ssh-manager.sh --help       # Show help
./ssh-manager.sh --version    # Show version
./ssh-manager.sh --quick-setup # Setup wizard for beginners
```

### Key Features

#### 🔐 Setting Up Passwordless Login
1. Run the tool: `./ssh-manager.sh`
2. Choose option **5** (Setup passwordless login wizard)
3. Follow the guided steps:
   - Generate or select an SSH key
   - Copy key to your server
   - Test the connection
   - Optionally add to SSH config

#### 🔑 Managing SSH Keys
- **Generate a new key:** Option 2
- **List existing keys:** Option 1
- **Copy key to server:** Option 6 (for techdana host)

#### 🌐 Managing Your Servers
- **Add SSH host:** Option 13
- **Test connection:** Option 15
- **Show SSH config:** Option 12

## 🎯 Perfect for Your Use Case

Since you mentioned you have a "techdana" host and want passwordless login, here's the workflow:

1. **Start the tool:** `./ssh-manager.sh`
2. **Choose option 6:** "Copy key to server"
3. **Select your existing key**
4. **Choose your techdana host** from the list
5. **Enter server password** when prompted
6. **Test the connection** automatically

## 🧭 Navigation

The tool features intuitive page-by-page navigation:
- **Enter:** Continue/Proceed
- **b:** Go back to previous menu
- **m:** Return to main menu
- **q:** Quit the application

## 🔒 Security Features

- **Permission checks** for SSH directory and keys
- **Weak key detection** (RSA < 2048 bits, deprecated DSA)
- **Automatic permission fixes**
- **Secure key generation** with modern algorithms
- **Backup functionality** before major operations

## 📋 Menu Overview

```
🔑 SSH Keys:
  1. List SSH keys
  2. Generate new SSH key
  3. Delete SSH key
  4. Change key passphrase

🔐 Passwordless Login:
  5. Setup passwordless login wizard
  6. Copy key to server
  7. Test passwordless connection

🤖 SSH Agent:
  8. Show agent status
  9. Add key to agent
 10. Add all keys to agent
 11. Remove key from agent

🌐 Connections:
 12. Show SSH config
 13. Add SSH host
 14. Remove SSH host
 15. Test SSH connection

🔧 Maintenance:
 16. Backup SSH config
 17. Restore SSH config
 18. Security check
 19. Fix permissions
```

## 🆘 Troubleshooting

If passwordless login isn't working:
1. **Use option 7** to test the connection
2. **Check SSH agent** with option 8
3. **Run security check** with option 18
4. **Try copying the key again** with option 6

## 🔧 Requirements

- **Bash 4.0+**
- **SSH client** (ssh, ssh-keygen, ssh-add)
- **macOS or Linux**
- **ssh-copy-id** (optional, tool has fallback)

## 📝 Examples

### Quick Setup for New Users
```bash
./ssh-manager.sh --quick-setup
```

### Setting Up Passwordless Login to techdana
```bash
./ssh-manager.sh
# Choose option 6 (Copy key to server)
# Select your key
# Choose techdana from the host list
# Enter password when prompted
# Test connection automatically
```

## 🚀 What's New in v2.0

- **Passwordless login wizard** with step-by-step guidance
- **Enhanced navigation** with breadcrumbs and back/forward
- **SSH key copying** functionality (ssh-copy-id equivalent)
- **Connection testing** with detailed troubleshooting
- **Improved UI** with better visual hierarchy
- **Host integration** with existing SSH configs

---

**Note:** This tool is designed for defensive security purposes and SSH management. It helps you securely manage your SSH infrastructure without requiring deep SSH knowledge.