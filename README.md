# DaTi Proxy

A tool that helps bypass network restrictions on remote servers by creating an SSH tunnel and Squid proxy.

![Version](https://img.shields.io/badge/version-1.0-blue)

> **Note**: Currently only compatible with Ubuntu-based systems using the APT package manager.

## Author

This script was created by [DaTi_Co]

## Table of Contents

- [Description](#description)
- [Requirements](#requirements)
- [Installation](#installation)
- [Usage](#usage)
- [Troubleshooting](#troubleshooting)
- [Disclaimer](#disclaimer)

## Description

The script sets up a proxy server on a remote server using SSH and Docker. It allows the user to configure their browser to use the proxy server for internet access. The script performs the following steps:

1. Asks the user for the remote server IP address, username, and port (optional).
2. Checks if the proxy configuration file already exists on the remote server.
3. If the proxy configuration file does not exist, adds the proxy configuration to the remote server's APT configuration.
4. Connects to the remote server using SSH and creates a remote port forwarding.
5. Checks if a Docker container with a Squid proxy server is already running.
6. If the Docker container is not running, starts a Docker container with a Squid proxy server.
7. Outputs the proxy server details (http://localhost:3128) for the user to configure their browser.
8. Defines a cleanup function to stop the Docker container, remove the proxy config file from APT, and close the SSH connection.
9. Calls the cleanup function if the user presses Ctrl+C or the script is terminated.
10. Waits for the user to press Ctrl+C to stop the script.

## Requirements

The script requires the following dependencies to be installed on the local machine:

- `sshpass` for password-based SSH authentication
- `docker` for running the Squid proxy
- SSH access to the remote server

## Installation

```bash
# Clone the repository
git clone https://github.com/username/DaTi-Proxy.git
cd DaTi-Proxy

# Make the script executable
chmod +x connect.sh
```

## Usage

Run the script and follow the interactive prompts:

```bash
./connect.sh
```

The script will ask for:
- Remote server IP address
- Username (defaults to your current user)
- SSH port (defaults to 22)
- Password

Once the script is running, on the remote server you can use:

```bash
sudo apt update
sudo apt install <package-name>
```

The traffic will be routed through your local machine's internet connection.


## Troubleshooting

**Connection issues:**
- Verify SSH credentials are correct
- Ensure the remote server allows SSH connections
- Check if port 3128 is available on your local machine

**APT issues:**
- Verify `/etc/apt/apt.conf.d/33proxy` exists on the remote server
- Check if Squid proxy is running with `docker ps | grep squid-proxy` on local machine

## Disclaimer

This tool is provided for educational purposes only. You are responsible for complying with all applicable laws and organizational policies when using this tool. Use at your own risk.