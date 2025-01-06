#!/bin/bash
echo "Channel Telegram: https://t.me/lazy_node"
echo "Website: https://lazynode.com"
echo "Stopping node and cleaning up processes..."
sudo pkill -f multiple-node
sleep 5

echo "Checking if processes are stopped..."
ps aux | grep -v grep | grep multiple-node

echo "Removing downloaded files and old installation..."
if [ -f "multipleforlinux.tar" ]; then
    rm -f multipleforlinux.tar
fi
if [ -d "multipleforlinux" ]; then
    rm -rf multipleforlinux
fi
sleep 2

echo "Node stopped and old files removed."

echo "Starting system update..."
sudo DEBIAN_FRONTEND=noninteractive apt update -y && sudo DEBIAN_FRONTEND=noninteractive apt upgrade -y

echo "Checking system architecture..."
ARCH=$(uname -m)
if [[ "$ARCH" == "x86_64" ]]; then
    CLIENT_URL="https://cdn.app.multiple.cc/client/linux/x64/multipleforlinux.tar"
elif [[ "$ARCH" == "aarch64" ]]; then
    CLIENT_URL="https://cdn.app.multiple.cc/client/linux/arm64/multipleforlinux.tar"
else
    echo "Unsupported system architecture: $ARCH"
    exit 1
fi

echo "Downloading the client from $CLIENT_URL..."
wget "$CLIENT_URL" -O multipleforlinux.tar

echo "Extracting files..."
tar -xvf multipleforlinux.tar

cd multipleforlinux

echo "Granting permissions..."
chmod +x ./multiple-cli
chmod +x ./multiple-node

echo "Adding directory to system PATH..."
echo "PATH=\$PATH:$(pwd)" >> ~/.bash_profile
source ~/.bash_profile

echo "Setting permissions..."
chmod -R 777 "$(pwd)"

echo "Launching multiple-node..."
nohup ./multiple-node > output.log 2>&1 &

# Read Account ID and PIN from external files instead of prompting
IDENTIFIER=$(cat ../account_id.txt)
PIN=$(cat ../pin.txt)

echo "Binding account with ID: $IDENTIFIER and PIN: $PIN..."
./multiple-cli bind --bandwidth-download 200 \
                    --identifier "$IDENTIFIER" \
                    --pin "$PIN" \
                    --storage 200 \
                    --bandwidth-upload 200

echo "Installation completed successfully!"
echo "Channel Telegram: https://t.me/lazy_node"
echo "Website: https://lazynode.com"



