# DaTi Proxy

IF YOU'RE TIRED OF NETWORK ADMINISTRATORS BLOCKING YOUR SERVER'S ACCESS TO THE INTERNET, THIS SCRIPT IS YOUR SECRET WEAPON! SAY GOODBYE TO INTERNET RESTRICTIONS AND HELLO TO FREEDOM!

Note: Right now, the script is only compatible with Ubuntu-based systems. and only apt package manager is supported.

## Author

This script was created by [DaTi_Co]

## Table of Contents

- [Description](#description)
- [Requirements](#requirements)
- [Installation](#installation)
- [Usage](#usage)

## Description

The DaTi Proxy script sets up a proxy server on a remote server using SSH and Docker. It allows the user to configure their browser to use the proxy server for internet access. The script performs the following steps:

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

- sshpass
- Docker

## Installation

To use the script, follow these steps:

1. Download the `connect.sh` file.
2. Open a terminal and navigate to the directory where the `connect.sh` file is located.
3. Run the command `chmod +x connect.sh` to make the script executable.

## Usage

To use the script, run it with the command `./connect.sh` in the terminal

## Disclaimer

IF YOU ARE USING THIS SCRIPT, YOU ARE RESPONSIBLE FOR ANY DAMAGE CAUSED BY IT. USE IT AT YOUR OWN RISK.