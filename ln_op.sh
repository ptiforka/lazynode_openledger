#!/bin/bash

# Exit on error
set -e
export DEBIAN_FRONTEND=noninteractive
# Remove old Docker installations
echo "Removing old Docker versions..."
sudo apt remove -y docker docker-engine docker.io containerd runc || true

# Install required dependencies
echo "Installing required dependencies..."
sudo apt install -y apt-transport-https ca-certificates curl software-properties-common
sudo apt install -y xvfb


# Add Docker's official GPG key and repository
echo "Adding Docker GPG key and repository..."
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker
echo "Installing Docker..."

sudo apt -y update
sudo apt install -y docker-ce docker-ce-cli containerd.io
sudo docker --version


# Install additional dependencies
echo "Installing additional dependencies for OpenLedger Node..."
sudo apt install -y libgtk-3-0 libnotify4 libnss3 libxss1 libxtst6 xdg-utils libatspi2.0-0 libsecret-1-0

# Download and install OpenLedger Node
echo "Downloading and installing OpenLedger Node..."
wget https://cdn.openledger.xyz/openledger-node-1.0.0-linux.zip -O openledger-node.zip
sudo apt install -y unzip
unzip openledger-node.zip
sudo dpkg -i openledger-node-1.0.0.deb || sudo apt-get install -f -y
sudo apt install -y desktop-file-utils
sudo dpkg --configure -a

# Install and configure VNC and XFCE
echo "Installing VNC and XFCE..."
sudo apt install -y tightvncserver xfce4 xfce4-goodies
sudo apt install -y mesa-utils libgl1-mesa-glx
sudo apt install -y vainfo libva-glx2 libva-drm2
sudo apt install -y dbus-x11
sudo service dbus start
sudo apt install -y mesa-utils libgl1-mesa-glx libegl1-mesa

# Install and configure XRDP
echo "Installing and configuring XRDP..."
sudo apt install -y xrdp
sudo systemctl enable xrdp
sudo systemctl start xrdp

# Configure SSH for X11 Forwarding
echo "Configuring SSH for X11 Forwarding..."
sed -i '/^#X11Forwarding /c\X11Forwarding yes' /etc/ssh/sshd_config
sed -i '/^#X11DisplayOffset /c\X11DisplayOffset 10' /etc/ssh/sshd_config
sed -i '/^#X11UseLocalhost /c\X11UseLocalhost yes' /etc/ssh/sshd_config
sudo systemctl restart sshd

password_file="password_to_server.txt"

# Check if the file exists and is not empty
if [[ -s "$password_file" ]]; then
    echo "Password already exists in $password_file: $(cat $password_file)"
else
    # Generate a random password with the format 'lazy****'
    password="lazy$(shuf -i 1000-9999 -n 1)"

    # Write the password to the file
    echo "$password" > "$password_file"
    echo "Random password saved to $password_file: $password"
fi

# Configure VNC
echo "Setting up VNC password..."
mkdir -p ~/.vnc
echo "$password" | vncpasswd -f > ~/.vnc/passwd
chmod 600 ~/.vnc/passwd


# Clean up lock files
echo "Removing stale VNC lock files..."
rm -f /tmp/.X1-lock
rm -f /tmp/.X11-unix/X1

# Start VNC server
echo "Starting VNC server..."
vncserver :1

# Launch OpenLedger Node in a screen session
echo "Launching OpenLedger Node in a screen session..."
sudo apt install -y screen
screen -dmS openledger bash -c "DISPLAY=:1 openledger-node --no-sandbox &> openledger.logs"

echo "Setup complete. OpenLedger Node is running in a screen session. Logs are available in 'openledger.logs'."
