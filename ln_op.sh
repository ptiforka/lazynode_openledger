  #!/bin/bash

# Exit immediately if any command fails
set -e

# Set non-interactive mode to prevent prompts
export DEBIAN_FRONTEND=noninteractive

# Configure needrestart to restart services automatically
echo "Configuring needrestart to auto-restart services..."
sudo sed -i 's/#\$nrconf{restart} = .*/\$nrconf{restart} = "a";/' /etc/needrestart/needrestart.conf || true

# Update and upgrade the system
echo "Updating and upgrading the system..."
sudo apt-get update -y
sudo apt-get -y -o Dpkg::Options::="--force-confnew" upgrade

# Remove old Docker versions
echo "Removing old Docker versions..."
sudo apt remove -y docker docker-engine docker.io containerd runc || true

# Install required dependencies
echo "Installing required dependencies..."
sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common gnupg

# Install Docker
echo "Installing Docker..."
sudo apt-get install -y docker-ce docker-ce-cli containerd.io
sudo docker --version


# Add Docker's GPG key and repository
echo "Adding Docker GPG key and repository..."
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null


# Install additional dependencies for OpenLedger Node
echo "Installing additional dependencies for OpenLedger Node..."
sudo apt-get install -y libgtk-3-0 libnotify4 libnss3 libxss1 libxtst6 xdg-utils libatspi2.0-0 libsecret-1-0 unzip screen
sudo apt install -y vainfo libva-glx2 libva-drm2 libva-x11-2

# Download and install OpenLedger Node
echo "Downloading and installing OpenLedger Node..."
wget https://cdn.openledger.xyz/openledger-node-1.0.0-linux.zip -O openledger-node.zip
unzip openledger-node.zip
sudo dpkg -i openledger-node-1.0.0.deb || sudo apt-get install -f -y
sudo apt-get install -y desktop-file-utils
sudo dpkg --configure -a

# Install VNC and XFCE
echo "Installing VNC and XFCE..."
sudo apt-get install -y tightvncserver xfce4 xfce4-goodies mesa-utils libgl1-mesa-glx vainfo libva-glx2 libva-drm2 dbus-x11 xrdp
sudo systemctl enable xrdp
sudo systemctl start xrdp

# Configure SSH for X11 Forwarding
echo "Configuring SSH for X11 Forwarding..."
sed -i '/^#X11Forwarding /c\X11Forwarding yes' /etc/ssh/sshd_config
sed -i '/^#X11DisplayOffset /c\X11DisplayOffset 10' /etc/ssh/sshd_config
sed -i '/^#X11UseLocalhost /c\X11UseLocalhost yes' /etc/ssh/sshd_config
sudo systemctl restart sshd

# Configure VNC password
echo "Setting up VNC password..."
mkdir -p ~/.vnc
echo "ln123" | vncpasswd -f > ~/.vnc/passwd
chmod 600 ~/.vnc/passwd

# Remove VNC lock files
echo "Removing old VNC lock files..."
rm -f /tmp/.X1-lock
rm -f /tmp/.X11-unix/X1

# Start VNC server
echo "Starting VNC server..."
vncserver :1

# Start OpenLedger Node in a screen session
echo "Launching OpenLedger Node in a screen session..."
screen -dmS openledger bash -c "DISPLAY=:1 openledger-node --no-sandbox &> openledger.logs"

# Final cleanup and reboot (if needed)
echo "Cleaning up and ensuring system stability..."


# Uncomment the following line if you want to reboot automatically after setup
# sudo reboot

echo "Setup completed successfully! OpenLedger Node is running in a screen session. Logs are in 'openledger.logs'."
