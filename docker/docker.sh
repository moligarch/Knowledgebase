#!/bin/bash

# Function to display help message
show_help() {
    echo "Usage: $(basename "$0") [options]"
    echo ""
    echo "Options:"
    echo "  --mirror URL          Use registry mirror (default: none)"
    echo "  --no-default-bridge   Disable default bridge network"
    echo "  --sudo               Add docker to system group (default: false)"
    echo "  -x, --uninstall      Uninstall Docker completely"
    echo ""
    echo "Example:"
    echo "  $(basename "$0") --mirror https://registry.docker.ir --no-default-bridge --sudo"
    echo "  $(basename "$0") --uninstall"
}

# Parse arguments using getopts
while getopts ":hm:snx" opt; do
    case $opt in
        h)
            show_help
            exit 0
            ;;
        m)
            REGISTRY_MIRROR="$OPTARG"
            ;;
        s)
            ADD_DOCKER_GROUP=true
            ;;
        n)
            NO_DEFAULT_BRIDGE=true
            ;;
        x)
            UNINSTALL=true
            ;;
        \?)
            echo "Invalid option: -$OPTARG"
            show_help
            exit 1
            ;;
    esac
done

# Default values
REGISTRY_MIRROR=${REGISTRY_MIRROR:-""}
ADD_DOCKER_GROUP=${ADD_DOCKER_GROUP:-false}
UNINSTALL=${UNINSTALL:-false}
NO_DEFAULT_BRIDGE=${NO_DEFAULT_BRIDGE:-false}

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
    sudo groupdel docker
    
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

# Add Docker's official GPG key
echo "Adding Docker's official GPG key..."
sudo apt-get update
sudo apt-get install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add repository to Apt sources
echo "Adding Docker repository..."
echo \
"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
$(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update

# Install Docker packages
echo "Installing Docker..."
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Configure daemon.json
echo "Configuring Docker daemon..."
set -x
sudo bash -c 'cat > /etc/docker/daemon.json <<EOF
{
'"${REGISTRY_MIRROR:+\"registry-mirrors\": [\""${REGISTRY_MIRROR}"\"],}"
'"${NO_DEFAULT_BRIDGE:+\"bridge\": \"none\"}"
}
EOF'
set +x

# Restart Docker service
sudo systemctl daemon-reload
sudo systemctl restart docker

# Configure Docker group if requested
if $ADD_DOCKER_GROUP; then
    echo "Adding docker to system group..."
    sudo addgroup --system docker
    sudo adduser $USER docker
fi

# Verify installation
echo "Verifying Docker installation..."
set -x
sudo docker run hello-world
set +x
