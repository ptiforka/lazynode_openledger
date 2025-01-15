while sudo fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 \
   || sudo fuser /var/lib/dpkg/lock >/dev/null 2>&1 \
   || sudo fuser /var/cache/apt/archives/lock >/dev/null 2>&1
do
  echo "Another apt or dpkg process is running. Waiting 5 seconds..."
  sleep 5
done

sudo DEBIAN_FRONTEND=noninteractive apt -y remove tightvncserver
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
if [[ ! -f "/etc/apt/keyrings/docker.gpg" ]]; then
    echo "Downloading and dearmoring Docker GPG key..."
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
        | sudo gpg --dearmor --batch --yes -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg
else
    echo "Docker GPG key already exists. Skipping overwrite."
fi
echo \
"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
$(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
# Update package index
echo "Updating package index..."
sudo DEBIAN_FRONTEND=noninteractive apt-get update -y
# Install Docker
echo "Installing Docker..."
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y docker-ce docker-ce-cli containerd.io
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
curl -o openledger-node.zip https://cdn.openledger.xyz/openledger-node-1.0.0-linux.zip

sudo DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends unzip
unzip -o openledger-node.zip
sudo DEBIAN_FRONTEND=noninteractive dpkg -i openledger-node-1.0.0.deb || sudo DEBIAN_FRONTEND=noninteractive apt-get install -f -y
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends desktop-file-utils
sudo DEBIAN_FRONTEND=noninteractive dpkg --configure -a
# Install and configure VNC and XFCE

echo "Installing VNC and XFCE..."
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    tigervnc-standalone-server \
    tigervnc-xorg-extension \
    tigervnc-standalone-server \
    tigervnc-xorg-extension \
    xfce4 \
    xfce4-goodies \
    xterm \
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

sudo rm /var/lib/dpkg/updates/*
sudo dpkg --configure -a
sudo apt install net-tools

# Configure VNC
echo "Setting up VNC password..."


echo "Setting VNC password..."
mkdir -p ~/.vnc
echo -e "$password" | vncpasswd -f > ~/.vnc/passwd
chmod 600 ~/.vnc/passwd
echo "VNC password set."

# Install missing fonts
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y xfonts-base xfonts-75dpi
# Remove stale lock files
echo "Cleaning up VNC lock files..."
rm -f /tmp/.X1-lock /tmp/.X11-unix/X1
sudo mkdir -p /var/lib/docker/tmp/
sudo chown -R root:docker /var/lib/docker/tmp/
sudo chmod -R 700 /var/lib/docker/tmp/
sudo systemctl restart docker
# Start VNC server
#!/bin/bash

# Define the VNC configuration file path
CONFIG_FILE="/etc/vnc.conf"

# Create the VNC configuration file with required settings

# Verify the configuration
if [ $? -eq 0 ]; then
  echo "VNC server restarted successfully with updated configuration."
else
  echo "Failed to restart VNC server. Please check the configuration or logs."
fi

echo "Starting VNC server..."
# Define the VNC configuration file path
CONFIG_FILE="/etc/vnc.conf"

# Create the VNC configuration file if it doesn't exist
if [ ! -f "$CONFIG_FILE" ]; then
  echo "Creating $CONFIG_FILE..."
  sudo touch "$CONFIG_FILE"
fi

# Add the MaxConnectionAttempts setting
echo "Setting MaxConnectionAttempts to 0..."
sudo bash -c "echo 'MaxConnectionAttempts=0' > $CONFIG_FILE"

mkdir -p ~/.vnc
echo "localhost=no" >> ~/.vnc/config
# Restart the VNC server

PID=$(lsof -t -i :5901)

if [ -n "$PID" ]; then
    echo "Found VNC server running on display :1 with PID: $PID"
    echo "Killing the process..."
    kill -9 $PID
    echo "Process $PID terminated."
else
    echo "No VNC server found on display :1."
fi

echo "Restarting the VNC server..."
vncserver -kill :1
vncserver :1

# Verify the configuration
if [ $? -eq 0 ]; then
  echo "VNC server restarted successfully with updated configuration."
else
  echo "Failed to restart the VNC server. Please check the logs."
fi


# Define the configuration directory
CONFIG_DIR="$HOME/.config/opl"

OLD_PORT=8080
NEW_PORT=7070

# Check if the configuration directory exists
if [ ! -d "$CONFIG_DIR" ]; then
  echo "Directory $CONFIG_DIR does not exist. Skipping port updates."
else
  # Check if the NEW_PORT is busy
  if sudo lsof -i :$NEW_PORT > /dev/null 2>&1; then
    echo "New port $NEW_PORT is already in use. Skipping port updates."
  else
    # Navigate to the configuration directory
    cd "$CONFIG_DIR" || { echo "Failed to navigate to $CONFIG_DIR. Skipping port updates."; }

    # Check if the OLD_PORT exists in the files
    if grep -q ":$OLD_PORT\b" config.yaml || grep -q "$OLD_PORT:$OLD_PORT" docker-compose.yaml; then
      echo "Old port $OLD_PORT found. Proceeding with changes..."

      # Update config.yaml
      echo "Updating config.yaml..."
      sed -i "s/:$OLD_PORT\b/:$NEW_PORT/g" config.yaml
      sed -i "s/http:\\/\\/opl_scraper:$OLD_PORT\b/http:\\/\\/opl_scraper:$NEW_PORT/g" config.yaml

      # Update docker-compose.yaml
      echo "Updating docker-compose.yaml..."
      sed -i "s/$OLD_PORT:$OLD_PORT/$NEW_PORT:$NEW_PORT/g" docker-compose.yaml

      # Verify changes
      echo "Changes applied. Verifying..."
      grep -E "$NEW_PORT|opl_scraper:$NEW_PORT" config.yaml docker-compose.yaml

      # Restart Docker containers
      docker stop opl_scraper opl_worker
      docker rm opl_scraper opl_worker
      echo "Docker containers restarted successfully. Changes completed."
    else
      echo "Old port $OLD_PORT not found. Skipping port updates."
    fi
  fi
fi

# Additional script logic continues here
echo "Continuing to the next part of the script..."


# Continue with the rest of the script
echo "Continuing with other operations..."
cd
# Launch OpenLedger Node in a screen session
echo "Launching OpenLedger Node in a screen session..."
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends screen
screen -dmS openledger bash -c "DISPLAY=:1 openledger-node --no-sandbox &> openledger.logs"

echo "Setup complete. OpenLedger Node is running in a screen session. Logs are available in 'openledger.logs'."
