# sshx

English | [简体中文](README_CN.md)

sshx is a command line tool for managing SSH connections. It provides a simple and intuitive interface for managing multiple SSH connections and executing commands on them.

<img alt="Welcome to sshx" src="https://raw.githubusercontent.com/zboyco/sshx/master/demo.gif" width="600" />

## Install

### Automatic Installation (Recommended)

> **Note: Requires sudo privileges to install sshx into /usr/local/bin.**

**Install via curl:**
```bash
curl -s https://raw.githubusercontent.com/zboyco/sshx/master/install.sh | sh
```

**Install via wget:**
```bash
wget https://raw.githubusercontent.com/zboyco/sshx/master/install.sh -O - | sh
```

### Manual Installation

If you prefer not to use the automatic installation script:

1. Download the script:
   ```bash
   curl -O https://raw.githubusercontent.com/zboyco/sshx/master/sshx.sh
   ```

2. Make it executable:
   ```bash
   chmod +x sshx.sh
   ```

3. Move it to a directory in your PATH:
   ```bash
   # Option 1: System-wide (requires sudo)
   sudo mv sshx.sh /usr/local/bin/sshx
   
   # Option 2: User-only (no sudo required)
   mkdir -p ~/.local/bin
   mv sshx.sh ~/.local/bin/sshx
   export PATH="$HOME/.local/bin:$PATH"  # Add to ~/.bashrc or ~/.zshrc
   ```

4. Verify installation:
   ```bash
   sshx --help
   ```

## Usage

```
sshx v0.1.1

Usage: sshx [command]

With no command, sshx will display a list of all saved connections.

Available commands:
  new              Add a new SSH configuration
  delete, rm       Delete an existing SSH configuration
  upgrade          Upgrade sshx to the latest version
  --help, -h       Display this help message
  --version, -v    Display version information

Environment variables:
  SSH_EXPECT_TIMEOUT    Set expect timeout (default: 30 seconds)
```

## Features

- 🚀 **Easy Management** - Simple command-line interface for managing SSH connections
- 🔐 **Multiple Authentication Methods** - Support for password and SSH key authentication
- 📝 **Configuration Description** - Add descriptions to your connections for easy identification
- 🗑️ **Easy Deletion** - Remove configurations you no longer need
- ⌨️ **Multiple Selection Methods** - Select connections by number or name
- 🔒 **Security Warnings** - Alerts when using potentially insecure authentication methods
- 📁 **trzsz Support** - Optional file transfer support with trzsz integration

## Important Note

> ⚠️ **Before using sshx:** It's strongly recommended to manually connect to your remote server at least once using the standard `ssh` command before adding it to sshx. This ensures the server's host key fingerprint is saved to `~/.ssh/known_hosts`.
>
> ```bash
> # Connect manually first to accept the host key
> ssh user@your-server.com
> # Type 'yes' when prompted about the host authenticity
> # Then exit and add the configuration to sshx
> ```
>
> This prevents connection failures due to host key verification prompts, especially when using password authentication with expect.

## Examples

### Add a new SSH connection

```bash
$ sshx new
Name for the new remote:
> my-server
Description for the new remote (optional):
> My production server
Hostname or IP address:
> 192.168.1.100
Port number (default is 22):
> 22
Username:
> admin
Password (optional, NOT RECOMMENDED for security reasons):
> [password hidden]

WARNING: Password will be stored in plain text in /Users/username/.ssh/remote
It is HIGHLY RECOMMENDED to use SSH key-based authentication instead.
Do you want to continue with password? (y/N):
> n

Path to private key file (optional):
> ~/.ssh/id_rsa

Do you want to use trzsz for file transfer support? (y/N):
> n
New ssh remote config saved: /Users/username/.ssh/remote/ssh-my-server
```

### List and connect to a saved connection

```bash
$ sshx
------------------------------------------------------------------
  No.  |  Name                  |  Description
-------+-----------------------+----------------------------------
  1    |  my-server             |  My production server
  2    |  dev-server            |  Development environment
------------------------------------------------------------------

Select a remote (input number or name, press Ctrl+C to exit):
> 1
# Connects to my-server
```

### Delete a connection

```bash
$ sshx delete
------------------------------------------------------------------
  No.  |  Name                  |  Description
-------+-----------------------+----------------------------------
  1    |  my-server             |  My production server
  2    |  dev-server            |  Development environment
------------------------------------------------------------------

Select a remote to delete (input number or name, press Ctrl+C to exit):
> 2

Are you sure you want to delete remote 'dev-server'? (y/N):
> y
Remote config 'dev-server' has been deleted.
```

### Upgrade sshx

```bash
$ sshx upgrade
sshx upgrade utility

Checking for updates...
Current version: v0.1.1
Latest version:  v0.2.0

A new version is available!

Do you want to upgrade to v0.2.0? (Y/n): y

Downloading latest version...
Installation location: /usr/local/bin/sshx
Current version backed up to: /usr/local/bin/sshx.backup

✓ Successfully upgraded to version v0.2.0

You can restore the previous version using:
  cp /usr/local/bin/sshx.backup /usr/local/bin/sshx
```

## Security Notes

- 🔐 **SSH Key Authentication Recommended** - For better security, use SSH key-based authentication instead of passwords
- ⚠️ **⚠️ IMPORTANT: Password Storage Warning ⚠️** - If you choose to use password authentication:
  - **Passwords are stored in PLAIN TEXT** in `~/.ssh/remote/` directory
  - Anyone with access to your user account can read these passwords
  - You can optionally enable clipboard copying when connecting (disabled by default for security)
  - This is NOT recommended for production or sensitive environments
  - **ALWAYS prefer SSH key-based authentication for security**
- 🔒 **File Permissions** - Configuration files are created with executable permissions only for the owner

## Requirements

- **bash** - The script is written in bash
- **expect** - Required only if using password-based authentication
- **ssh** - OpenSSH client
- **trzsz** (optional) - For file transfer support. Install from https://github.com/trzsz/trzsz

## Configuration Storage

All SSH configurations are stored in `~/.ssh/remote/` directory with the prefix `ssh-`. Each configuration is a separate executable script.

### Running Configuration Scripts Directly

You can execute the configuration scripts directly without using `sshx`:

```bash
# Execute directly with full path
~/.ssh/remote/ssh-my-server

# Or add the directory to your PATH in ~/.bashrc or ~/.zshrc
export PATH="$HOME/.ssh/remote:$PATH"

# Then you can run directly by name
ssh-my-server
```

This allows you to:
- Create shortcuts to your favorite servers
- Integrate with other tools and scripts
- Bypass the sshx menu for quick access

## trzsz File Transfer

If you enable trzsz support when creating a connection, you can use `trz` and `tsz` commands to transfer files during your SSH session:

- **trz** - Receive files from remote to local (like `rz`)
- **tsz** - Send files from local to remote (like `sz`)

**Example usage:**
```bash
# On remote server, download file to local
tsz file.txt

# On remote server, upload file from local
trz
```

**Installation:**
- macOS: `brew install trzsz-ssh`
- Linux: Download from https://github.com/trzsz/trzsz/releases
- More info: https://trzsz.github.io/

## FAQ & Troubleshooting

### How to use SSH key authentication?

When adding a configuration, leave the password empty, then enter the private key file path (usually `~/.ssh/id_rsa`).

### expect command not found / Password authentication not working

**Problem:** When using password authentication, you get "expect: command not found"

**Solution:** Install expect:
```bash
# macOS
brew install expect

# Ubuntu/Debian
sudo apt-get install expect

# CentOS/RHEL
sudo yum install expect
```

### Permission denied when executing configuration

**Problem:** Configuration file exists but cannot be executed

**Solution:** Make sure the configuration file has executable permissions:
```bash
chmod +x ~/.ssh/remote/ssh-your-config-name
```

### Private key file not found or not readable

**Problem:** Error when using SSH key authentication

**Solution:** 
1. Verify the key file exists:
   ```bash
   ls -l ~/.ssh/id_rsa
   ```

2. Check file permissions (should be 600 or 400):
   ```bash
   chmod 600 ~/.ssh/id_rsa
   ```

3. Use absolute path when adding configuration:
   ```bash
   /home/username/.ssh/id_rsa
   # or
   ~/.ssh/id_rsa
   ```

### trzsz command not found

**Problem:** Enabled trzsz but command is not available

**Solution:** Install trzsz as mentioned in the [trzsz File Transfer](#trzsz-file-transfer) section, or recreate the configuration without trzsz support.

### Connection works manually but fails through sshx

**Problem:** SSH connection works with `ssh user@host` but fails when using sshx configuration

**Solution:**
1. Check the generated configuration file:
   ```bash
   cat ~/.ssh/remote/ssh-your-config-name
   ```

2. Try executing it directly to see the error:
   ```bash
   bash ~/.ssh/remote/ssh-your-config-name
   ```

3. Verify all paths (SSH keys) are absolute paths

### Configurations not showing up

**Problem:** Added configurations but they don't appear in the list

**Solution:**
1. Check the configuration directory:
   ```bash
   ls -la ~/.ssh/remote/
   ```

2. Ensure files have the correct prefix `ssh-` and are executable:
   ```bash
   chmod +x ~/.ssh/remote/ssh-*
   ```

## Uninstall

To completely remove sshx from your system:

1. Remove the sshx command:
   ```bash
   # If installed system-wide
   sudo rm /usr/local/bin/sshx
   
   # If installed in user directory
   rm ~/.local/bin/sshx
   ```

2. (Optional) Remove all saved configurations:
   ```bash
   rm -rf ~/.ssh/remote/
   ```
   
   ⚠️ **Warning:** This will delete all your saved SSH configurations. Make sure to backup if needed.

3. (Optional) Remove from PATH if you added it manually:
   ```bash
   # Edit ~/.bashrc or ~/.zshrc and remove the line:
   # export PATH="$HOME/.local/bin:$PATH"
   ```

## License

MIT