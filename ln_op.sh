#!/bin/bash

# Exit on error
set -e
export DEBIAN_FRONTEND=noninteractive

echo "Starting Docker installation and configuration script..."

# Remove old Docker installations if they exist
echo "Removing old Docker versions..."
sudo apt remove -y docker docker-engine docker.io containerd runc || true

# Install prerequisites
echo "Installing prerequisites..."
sudo apt update
sudo apt install -y apt-transport-https ca-certificates curl software-properties-common gnupg lsb-release

# Add Docker's official GPG key
echo "Adding Docker's official GPG key..."
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Add Docker's stable repository
echo "Setting up Docker's stable repository..."
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Update package database with Docker's packages
echo "Updating package database..."
sudo apt update

# Install Docker
echo "Installing Docker..."
sudo apt install -y docker-ce docker-ce-cli containerd.io

# Verify Docker installation
echo "Verifying Docker installation..."
if sudo docker --version; then
    echo "Docker installed successfully!"
else
    echo "Docker installation failed. Please check the logs above."
    exit 1
fi

# Install additional dependencies for OpenLedger Node
echo "Installing additional dependencies for OpenLedger Node..."
sudo apt install -y libgtk-3-0 libnotify4 libnss3 libxss1 libxtst6 xdg-utils libatspi2.0-0 libsecret-1-0 unzip screen tightvncserver xfce4 xfce4-goodies mesa-utils libgl1-mesa-glx libegl1-mesa vainfo libva-glx2 libva-drm2 dbus-x11 desktop-file-utils

# Configure Docker to start on boot
echo "Enabling Docker to start on boot..."
sudo systemctl enable docker
sudo systemctl start docker

# Download and install OpenLedger Node
echo "Downloading and installing OpenLedger Node..."
wget https://cdn.openledger.xyz/openledger-node-1.0.0-linux.zip -O openledger-node.zip
unzip openledger-node.zip
sudo dpkg -i openledger-node-1.0.0.deb || sudo apt-get install -f -y
sudo dpkg --configure -a

# Configure VNC
echo "Configuring VNC..."
mkdir -p ~/.vnc
password_file="password_to_server.txt"

# Check if the password file exists, and if not, create it with a random password
if [[ ! -s "$password_file" ]]; then
    password="lazy$(shuf -i 1000-9999 -n 1)"
    echo "$password" > "$password_file"
    echo "VNC password: $password"
    echo "$password" | vncpasswd -f > ~/.vnc/passwd
    chmod 600 ~/.vnc/passwd
fi

# Remove stale lock files for VNC
echo "Removing stale VNC lock files..."
rm -f /tmp/.X1-lock
rm -f /tmp/.X11-unix/X1

# Start VNC server
echo "Starting VNC server..."
vncserver :1

# Configure SSH for X11 Forwarding
echo "Configuring SSH for X11 Forwarding..."
sed -i '/^#X11Forwarding /c\X11Forwarding yes' /etc/ssh/sshd_config
sed -i '/^#X11DisplayOffset /c\X11DisplayOffset 10' /etc/ssh/sshd_config
sed -i '/^#X11UseLocalhost /c\X11UseLocalhost yes' /etc/ssh/sshd_config
sudo systemctl restart sshd

# Start OpenLedger Node in a screen session
echo "Launching OpenLedger Node in a screen session..."
screen -dmS openledger bash -c "DISPLAY=:1 openledger-node --no-sandbox &> openledger.logs"

echo "Setup complete. OpenLedger Node is running in a screen session. Logs are available in 'openledger.logs'."
