#!/bin/bash

# Function to display help message
show_help() {
    echo "Usage: $(basename "$0") [options]"
    echo ""
    echo "Options:"
    echo "  --mirror URL          Use registry mirror (default: none)"
    echo "  --no-default-bridge   Disable default bridge network"
    echo "  --sudo                Add user to docker group (default: false)"
    echo "  -x, --uninstall       Uninstall Docker completely"
    echo ""
    echo "Example:"
    echo "  ./$(basename "$0") --mirror https://registry.docker.ir --no-default-bridge --sudo"
    echo "  ./$(basename "$0") --uninstall"
}

# Parse arguments using getopt
OPTS=$(getopt -o hxsm:n --long help,uninstall,sudo,mirror:,no-default-bridge -n 'docker.sh' -- "$@") || exit 1
eval set -- "$OPTS"

# Default values
REGISTRY_MIRROR=""
ADD_DOCKER_GROUP=false
UNINSTALL=false
NO_DEFAULT_BRIDGE=false

# Process options
while true; do
    case "$1" in
        -h|--help)
            show_help
            exit 0
            ;;
        -m|--mirror)
            REGISTRY_MIRROR="$2"
            shift 2
            ;;
        -s|--sudo)
            ADD_DOCKER_GROUP=true
            shift
            ;;
        -n|--no-default-bridge)
            NO_DEFAULT_BRIDGE=true
            shift
            ;;
        -x|--uninstall)
            UNINSTALL=true
            shift
            ;;
        --)
            shift
            break
            ;;
        *)
            echo "Invalid option: $1" >&2
            show_help
            exit 1
            ;;
    esac
done

# Handle uninstall option
if $UNINSTALL; then
    echo "Uninstalling Docker completely..."
    
    # Stop Docker service
    echo "Stopping Docker service..."
    sudo systemctl stop docker.service || true
    
    # Remove Docker packages
    echo "Removing Docker packages..."
    sudo apt-get purge -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    # Remove Docker configuration and data
    echo "Removing Docker configuration and data..."
    sudo rm -rf /var/lib/docker /etc/docker /var/lib/containerd
    
    # Remove Docker group
    echo "Removing Docker group..."
    sudo groupdel docker >/dev/null 2>&1 || true
    
    # Remove Docker socket
    echo "Removing Docker socket..."
    sudo rm -rf /var/run/docker.sock
    
    # Clean up user configuration
    echo "Cleaning up user configuration..."
    rm -rf ~/.docker
    
    # Remove unused dependencies
    echo "Removing unused dependencies..."
    sudo apt-get autoremove -y --purge
    
    echo "Docker has been completely uninstalled."
    exit 0
fi

# Install dependencies
echo "Adding Docker's official GPG key..."
sudo apt-get update
sudo apt-get install -y ca-certificates curl

# Add Docker repository
echo "Adding Docker repository..."
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
$(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update

# Install Docker packages
echo "Installing Docker..."
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Configure daemon.json
echo "Configuring Docker daemon..."
DAEMON_JSON_CONTENT="{"
if [ -n "$REGISTRY_MIRROR" ]; then
    DAEMON_JSON_CONTENT+="\"registry-mirrors\": [\"${REGISTRY_MIRROR}\"]"
    if $NO_DEFAULT_BRIDGE; then
        DAEMON_JSON_CONTENT+=", "
    fi
fi
if $NO_DEFAULT_BRIDGE; then
    DAEMON_JSON_CONTENT+="\"bridge\": \"none\""
fi
DAEMON_JSON_CONTENT+="}"

sudo bash -c "cat > /etc/docker/daemon.json <<EOF
$DAEMON_JSON_CONTENT
EOF"

# Restart Docker service
sudo systemctl daemon-reload
sudo systemctl restart docker

# Configure Docker group if requested
if $ADD_DOCKER_GROUP; then
    echo "Adding user to docker group..."
    if ! getent group docker >/dev/null; then
        sudo addgroup --system docker
    fi
    sudo usermod -aG docker "$USER"
    echo "User $USER added to docker group. You may need to log out and back in for changes to take effect."
fi

# Verify installation
echo "Verifying Docker installation..."
sudo docker run --rm hello-world
