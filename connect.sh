#!/bin/bash
# Author: DaTi_Co
# Description: Sets up an SSH tunnel and Squid proxy to enable internet access on remote Ubuntu servers
# Usage: ./connect.sh

echo "Enter the remote server IP address: "
read -r remote_server

echo "Enter the remote server username (default $USER): "
read -r remote_username

echo "Enter the remote server port (default 22): "
read -r remote_port

read -rs -p "Enter the remote server password: " remote_password

remote_port=${remote_port:-22}
remote_username=${remote_username:-$USER}

# temporary hard-coded values for testing
# Import variables from .env file
# source "./.env"
# temporary hard-coded values for testing

echo "Checking if the proxy configuration file exists on the remote server"
if ! sshpass -p "$remote_password" ssh -p "$remote_port" "$remote_username"@"$remote_server" "[ -f /etc/apt/apt.conf.d/33proxy ]"; then
    echo "Adding proxy configuration to the remote server's APT configuration"
    sshpass -p "$remote_password" ssh -p "$remote_port" "$remote_username"@"$remote_server" "echo 'Acquire::http::Proxy \"http://localhost:3128\";' | sudo -S tee /etc/apt/apt.conf.d/33proxy <<< \"$remote_password\""
else
    echo "Proxy configuration file already exists on the remote server"
fi

# Connect to the remote server using SSH and create a remote port forwarding
sshpass -p "$remote_password" ssh -N -R 3128:localhost:3128 -p "$remote_port" "$remote_username"@"$remote_server" &
echo "Connected to the remote server and created a remote port forwarding"

# Check if the Docker container is already running
echo "Checking if the Docker container with a Squid proxy server is already running"
if ! docker ps -q -f name=squid-proxy >/dev/null; then
    echo "Starting the Docker container with a Squid proxy server"
    docker run -d --name squid-proxy -p 3128:3128 ubuntu/squid:latest
    echo "Changing Squid configuration to allow all requests"
    docker exec squid-proxy sed -i 's/http_access deny all/http_access allow all/g' /etc/squid/squid.conf
fi

echo "Proxy server: http://localhost:3128"

# stop the Docker container, remove the proxy config file from APT, and close the SSH connection 
function cleanup() {
    echo 
    echo "Cleaning up and stopping the proxy server"
    echo "Checking if the Docker container is running"
    if docker ps -q -f name=squid-proxy &>/dev/null; then
        echo "Stopping and removing Docker container..."
        docker stop squid-proxy || echo "Warning: Failed to stop container"
        docker rm squid-proxy || echo "Warning: Failed to remove container"
    fi
    echo "Checking if the proxy configuration file exists on the remote server"
    if sshpass -p "$remote_password" ssh -p "$remote_port" "$remote_username"@"$remote_server" "[ -f /etc/apt/apt.conf.d/33proxy ]"; then
        echo "Removing proxy configuration from remote server..."
        sshpass -p "$remote_password" ssh -p "$remote_port" "$remote_username"@"$remote_server" "sudo -S rm /etc/apt/apt.conf.d/33proxy <<< \"$remote_password\"" || echo "Warning: Failed to remove proxy configuration"
    fi
    echo "Checking if the SSH connection is still active"
    if pgrep -f "ssh -N -R 3128:localhost:3128 -p $remote_port $remote_username@$remote_server" >/dev/null; then
        # Close the SSH connection
        echo "Closing the SSH connection"
        pkill -f "ssh -N -R 3128:localhost:3128 -p $remote_port $remote_username@$remote_server"
    fi
    echo "Cleaned up Docker container and removed proxy configuration from remote server"
}


# Call the cleanup function if the user presses Ctrl+C or the script is terminated
trap cleanup EXIT

# Wait for the user to press Ctrl+C to stop the script
echo "Press Ctrl+C to stop the proxy server and clean up"
sleep infinity
