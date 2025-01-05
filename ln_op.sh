#!/bin/bash

# Exit on error
set -e
export DEBIAN_FRONTEND=noninteractive

# Remove old Docker installations
echo "Removing old Docker versions..."
sudo DEBIAN_FRONTEND=noninteractive apt-get purge -y docker docker-engine docker.io containerd runc || true
sudo rm -rf /var/lib/docker /etc/docker

# Install required dependencies
echo "Installing required dependencies..."
sudo DEBIAN_FRONTEND=noninteractive apt-get update -y
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    software-properties-common \
    gnupg \
    lsb-release

# Add Docker's official GPG key and repository
echo "Adding Docker GPG key and repository..."
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo \
"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
$(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Update package index
echo "Updating package index..."
sudo DEBIAN_FRONTEND=noninteractive apt-get update -y

# Install Docker
echo "Installing Docker..."
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y docker-ce docker-ce-cli containerd.io || {
    echo "Docker installation failed. Check repository configuration or package availability."
    exit 1
}
sudo docker --version

# Install additional dependencies for OpenLedger Node
echo "Installing additional dependencies for OpenLedger Node..."
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    libgtk-3-0 \
    libnotify4 \
    libnss3 \
    libxss1 \
    libxtst6 \
    xdg-utils \
    libatspi2.0-0 \
    libsecret-1-0 \
    libasound2

# Download and install OpenLedger Node
echo "Downloading and installing OpenLedger Node..."
wget https://cdn.openledger.xyz/openledger-node-1.0.0-linux.zip -O openledger-node.zip || {
    echo "Failed to download OpenLedger Node. Check the URL or network connection."
    exit 1
}
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends unzip
unzip openledger-node.zip
sudo DEBIAN_FRONTEND=noninteractive dpkg -i openledger-node-1.0.0.deb || sudo DEBIAN_FRONTEND=noninteractive apt-get install -f -y
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends desktop-file-utils
sudo DEBIAN_FRONTEND=noninteractive dpkg --configure -a

# Install and configure VNC and XFCE
echo "Installing VNC and XFCE..."
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    tightvncserver \
    xfce4 \
    xfce4-goodies \
    mesa-utils \
    libgl1-mesa-glx \
    vainfo \
    libva-glx2 \
    libva-drm2 \
    dbus-x11 \
    libegl1-mesa
sudo systemctl is-active --quiet dbus || sudo systemctl start dbus

# Install and configure XRDP
echo "Installing and configuring XRDP..."
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends xrdp
sudo systemctl enable xrdp
sudo systemctl start xrdp

# Configure SSH for X11 Forwarding
echo "Configuring SSH for X11 Forwarding..."
sudo sed -i '/^#X11Forwarding /c\X11Forwarding yes' /etc/ssh/sshd_config
sudo sed -i '/^#X11DisplayOffset /c\X11DisplayOffset 10' /etc/ssh/sshd_config
sudo sed -i '/^#X11UseLocalhost /c\X11UseLocalhost yes' /etc/ssh/sshd_config
sudo systemctl restart sshd

# Generate or retrieve the VNC password
password_file="password_to_server.txt"
if [[ -s "$password_file" ]]; then
    password=$(cat "$password_file")
    echo "Using existing password: $password"
else
    password="lazy$(shuf -i 1000-9999 -n 1)"
    echo "$password" > "$password_file"
    echo "Generated password: $password"
fi

# Configure VNC
echo "Setting up VNC password..."
mkdir -p ~/.vnc
echo "$password" | vncpasswd -f > ~/.vnc/passwd
chmod 600 ~/.vnc/passwd


sudo DEBIAN_FRONTEND=noninteractive apt-get install -y xfonts-base xfonts-75dpi

# Remove stale lock files
echo "Cleaning up VNC lock files..."
rm -f /tmp/.X1-lock /tmp/.X11-unix/X1

# Start VNC server
echo "Starting VNC server..."
vncserver :1

# Launch OpenLedger Node in a screen session
echo "Launching OpenLedger Node in a screen session..."
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends screen
screen -dmS openledger bash -c "DISPLAY=:1 openledger-node --no-sandbox &> openledger.logs"

echo "Setup complete. OpenLedger Node is running in a screen session. Logs are available in 'openledger.logs'."
