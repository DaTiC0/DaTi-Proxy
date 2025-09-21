#!/bin/bash
# Author: DaTi_Co
# Description: Sets up an SSH tunnel and Squid proxy to enable internet access on remote Ubuntu servers
# Usage: ./connect.sh

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# Configuration constants
readonly PROXY_PORT=3128
readonly CONTAINER_NAME="squid-proxy"
readonly PROXY_CONFIG_FILE="/etc/apt/apt.conf.d/33proxy"
readonly DOCKER_IMAGE="ubuntu/squid:latest"

# Global variables
remote_server=""
remote_username=""
remote_port=""
remote_password=""

# Function to log messages with timestamp
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

# Function to log error messages
log_error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $*" >&2
}

# Function to validate IP address
validate_ip() {
    local ip="$1"
    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        IFS='.' read -ra ADDR <<< "$ip"
        for i in "${ADDR[@]}"; do
            if [[ $i -gt 255 ]]; then
                return 1
            fi
        done
        return 0
    fi
    return 1
}

# Function to validate port number
validate_port() {
    local port="$1"
    if [[ $port =~ ^[0-9]+$ ]] && [ "$port" -ge 1 ] && [ "$port" -le 65535 ]; then
        return 0
    fi
    return 1
}

# Function to collect and validate user input
collect_user_input() {
    log "Collecting connection details..."
    
    while true; do
        read -r -p "Enter the remote server IP address: " remote_server
        if validate_ip "$remote_server"; then
            break
        else
            log_error "Invalid IP address format. Please try again."
        fi
    done
    
    read -r -p "Enter the remote server username [$USER]: " remote_username
    remote_username=${remote_username:-$USER}
    
    while true; do
        read -r -p "Enter the remote server port [22]: " remote_port
        remote_port=${remote_port:-22}
        if validate_port "$remote_port"; then
            break
        else
            log_error "Invalid port number. Please enter a port between 1-65535."
        fi
    done
    
    read -rs -p "Enter the remote server password: " remote_password
    echo  # New line after password input
    
    if [[ -z "$remote_password" ]]; then
        log_error "Password cannot be empty"
        exit 1
    fi
}

# Function to execute SSH commands with error handling
execute_ssh_command() {
    local command="$1"
    local description="${2:-Executing SSH command}"
    
    log "$description"
    if ! sshpass -p "$remote_password" ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no -p "$remote_port" "$remote_username"@"$remote_server" "$command"; then
        log_error "Failed: $description"
        return 1
    fi
    return 0
}

# Function to check if proxy configuration exists on remote server
check_proxy_config() {
    execute_ssh_command "[ -f $PROXY_CONFIG_FILE ]" "Checking if proxy configuration file exists"
}

# Function to add proxy configuration to remote server
add_proxy_config() {
    log "Adding proxy configuration to remote server APT"
    local proxy_config="Acquire::http::Proxy \"http://localhost:$PROXY_PORT\";"
    if ! execute_ssh_command "echo '$proxy_config' | sudo -S tee $PROXY_CONFIG_FILE <<< \"$remote_password\"" "Adding proxy configuration"; then
        log_error "Failed to add proxy configuration"
        exit 1
    fi
}

# Function to manage proxy configuration
manage_proxy_config() {
    log "Managing proxy configuration on remote server"
    if ! check_proxy_config; then
        add_proxy_config
    else
        log "Proxy configuration file already exists on remote server"
    fi
}

# Function to create SSH tunnel
create_ssh_tunnel() {
    log "Creating SSH tunnel with remote port forwarding"
    sshpass -p "$remote_password" ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no -N -R "$PROXY_PORT:localhost:$PROXY_PORT" -p "$remote_port" "$remote_username"@"$remote_server" &
    local ssh_pid=$!
    
    # Give the SSH connection a moment to establish
    sleep 2
    
    # Check if SSH process is still running
    if ! kill -0 $ssh_pid 2>/dev/null; then
        log_error "Failed to create SSH tunnel"
        exit 1
    fi
    
    log "SSH tunnel created successfully"
}

# Function to check if Docker container is running
is_container_running() {
    docker ps -q -f name="$CONTAINER_NAME" &>/dev/null
}

# Function to start Docker container with Squid proxy
start_squid_container() {
    log "Starting Docker container with Squid proxy server"
    if ! docker run -d --name "$CONTAINER_NAME" -p "$PROXY_PORT:$PROXY_PORT" "$DOCKER_IMAGE"; then
        log_error "Failed to start Docker container"
        exit 1
    fi
    
    # Wait for container to be ready
    sleep 5
    
    log "Configuring Squid to allow all requests"
    if ! docker exec "$CONTAINER_NAME" sed -i 's/http_access deny all/http_access allow all/g' /etc/squid/squid.conf; then
        log_error "Failed to configure Squid"
        exit 1
    fi
    
    # Restart squid to apply configuration
    docker exec "$CONTAINER_NAME" service squid restart
}

# Function to manage Docker container
manage_docker_container() {
    log "Managing Docker container"
    if ! is_container_running; then
        start_squid_container
    else
        log "Docker container with Squid proxy is already running"
    fi
}

# Function to stop and remove Docker container
cleanup_docker() {
    log "Checking if Docker container is running"
    if is_container_running; then
        log "Stopping and removing Docker container..."
        if ! docker stop "$CONTAINER_NAME" 2>/dev/null; then
            log_error "Failed to stop container"
        fi
        if ! docker rm "$CONTAINER_NAME" 2>/dev/null; then
            log_error "Failed to remove container"
        fi
    else
        log "Docker container is not running"
    fi
}

# Function to remove proxy configuration from remote server
cleanup_proxy_config() {
    log "Checking if proxy configuration file exists on remote server"
    if check_proxy_config; then
        log "Removing proxy configuration from remote server..."
        if ! execute_ssh_command "sudo -S rm $PROXY_CONFIG_FILE <<< \"$remote_password\"" "Removing proxy configuration"; then
            log_error "Failed to remove proxy configuration"
        fi
    else
        log "Proxy configuration file does not exist on remote server"
    fi
}

# Function to close SSH connection
cleanup_ssh() {
    log "Checking if SSH connection is still active"
    local ssh_pattern="ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no -N -R $PROXY_PORT:localhost:$PROXY_PORT -p $remote_port $remote_username@$remote_server"
    if pgrep -f "$ssh_pattern" >/dev/null; then
        log "Closing SSH connection"
        pkill -f "$ssh_pattern"
    else
        log "SSH connection is not active"
    fi
}

# Main cleanup function
cleanup() {
    echo
    log "Cleaning up and stopping proxy server"
    cleanup_docker
    cleanup_proxy_config
    cleanup_ssh
    log "Cleanup completed"
}

# Function to display proxy information
show_proxy_info() {
    echo
    log "=== PROXY SERVER READY ==="
    log "Proxy server: http://localhost:$PROXY_PORT"
    log "Configure your browser or applications to use this proxy"
    log "Press Ctrl+C to stop the proxy server and clean up"
    echo
}

# Main function
main() {
    log "Starting DaTi Proxy setup"
    
    # Collect user input
    collect_user_input
    
    # Setup proxy configuration on remote server
    manage_proxy_config
    
    # Create SSH tunnel
    create_ssh_tunnel
    
    # Setup Docker container
    manage_docker_container
    
    # Show proxy information
    show_proxy_info
    
    # Setup cleanup trap and wait
    trap cleanup EXIT
    sleep infinity
}

# Execute main function
main "$@"
