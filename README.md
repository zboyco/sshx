# sshx

sshx is a command line tool for managing SSH connections. It provides a simple and intuitive interface for managing multiple SSH connections and executing commands on them.

<img alt="Welcome to sshx" src="https://raw.githubusercontent.com/zboyco/sshx/master/demo.gif" width="600" />

## Install

> **Note: Requires sudo privileges to install sshx into /usr/local/bin.**  
Or you can download the sshx.sh file and manually add it to the environment variable.

### Install sshx via curl

```
curl -s https://raw.githubusercontent.com/zboyco/sshx/master/install.sh | sh
```

### Install sshx via wget

```
wget https://raw.githubusercontent.com/zboyco/sshx/master/install.sh -O - | sh
```

## Usage

```
Usage: sshx [command]

With no command, sshx will display a list of all saved connections.

Available commands:
  new           Create a new SSH connection
  --help, -h    Display this help message
```