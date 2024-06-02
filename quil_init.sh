#!/bin/bash

# Utils: Update or add specific line to a file
update_or_add_line() {
  local file=$1
  local search=$2
  local replace=$3

  # if file exists
  if [ -f "$file" ]; then
    # Check if the search term exists in the file
    if grep -q "^$search" "$file"; then
      # Replace the line if it exists
      sed -i "s|^$search.*|$replace|" "$file"
      echo "Updated: $replace in $file"
    else
      # Add the line if it does not exist
      echo "$replace" >> "$file"
      echo "Added: $replace to $file"
    fi
  else
    echo "File not found: $file"
  fi
}

# Function: Initial setup for first-time use
init() {
  # Check if Go is installed
  if ! command -v go &> /dev/null; then
    # Download and install Go
    wget https://go.dev/dl/go1.20.14.linux-amd64.tar.gz && \
    sudo tar -xvf go1.20.14.linux-amd64.tar.gz && \
    sudo mv go /usr/local && \
    sudo rm go1.20.14.linux-amd64.tar.gz
  else
    echo "Go is already installed."
  fi
  
  # Install Git
  sudo apt-get update && sudo apt-get install -y git

  # Configure Go environment variables
  update_or_add_line ~/.bashrc 'GOROOT=' 'GOROOT=/usr/local/go'
  update_or_add_line ~/.bashrc 'GOPATH=' 'GOPATH=$HOME/go'
  update_or_add_line ~/.bashrc 'PATH=$GOPATH' 'PATH=$GOPATH/bin:$GOROOT/bin:$PATH'

  # Update the network buffer sizes
  update_or_add_line /etc/sysctl.conf '# Increase buffer sizes for better network performance' '# Increase buffer sizes for better network performance'
  update_or_add_line /etc/sysctl.conf 'net.core.rmem_max=' 'net.core.rmem_max=600000000'
  update_or_add_line /etc/sysctl.conf 'net.core.wmem_max=' 'net.core.wmem_max=600000000'

  # Apply the changes to sysctl
  sudo sysctl -p

  # Clone the Ceremony Client repository
  git clone https://source.quilibrium.com/quilibrium/ceremonyclient.git ~/ceremonyclient

  # Enable UFW and allow ports 22, 8336, and 443
  if echo "y" | sudo ufw enable; then
    sudo ufw allow 22
    sudo ufw allow 8336
    sudo ufw allow 443
    sudo ufw status
  else
    echo "Failed to enable UFW. Please check the firewall settings manually."
  fi

  # Switch to the release branch
  cd ~/ceremonyclient/node
  git checkout release

  sudo bash -c 'cat > /lib/systemd/system/ceremonyclient.service <<EOF
[Unit]
Description=Ceremony Client Go App Service
[Service]
Type=simple
Restart=always
RestartSec=5s
WorkingDirectory=/root/ceremonyclient/node
Environment=GOEXPERIMENT=arenas
ExecStart=/root/ceremonyclient/node/node-1.4.18-linux-amd64
[Install]
WantedBy=multi-user.target
EOF'

  # Update the WorkingDirectory and ExecStart paths in the service file to the current user's home directory
  cd ~
  root_dir=$(pwd)
  sudo sed -i "s|WorkingDirectory=.*|WorkingDirectory=${root_dir}/ceremonyclient/node|" /lib/systemd/system/ceremonyclient.service
  sudo sed -i "s|ExecStart=.*|ExecStart=${root_dir}/ceremonyclient/node/node-1.4.18-linux-amd64|" /lib/systemd/system/ceremonyclient.service

  # Remind the user to reload the bashrc and reboot the system
  echo "Please run 'source ~/.bashrc' to update your environment, then run 'go version' to verify the installation."
  echo "After that, please reboot the system to apply the UFW changes"
}

# Function: Verify the current setup
verify() {
  # Display the current UFW status
  echo -e "\033[1mCurrent UFW status:\033[0m"
  sudo ufw status
  echo ""

  # Display the current Go version
  echo -e "\033[1mCurrent go version:\033[0m"
  go version
  echo ""

  # Display the current network settings
  echo -e "\033[1mCurrent network settings:\033[0m"
  sudo sysctl -p
  echo ""

  # Display config.yml
  echo -e "\033[1mCurrent config.yml settings:\033[0m"
  grep 'listenGrpcMultiaddr:' ~/ceremonyclient/node/.config/config.yml
  grep 'statsMultiaddr:' ~/ceremonyclient/node/.config/config.yml
  echo ""

  # Display the current service configuration
  echo -e "\033[1mCurrent service configuration:\033[0m"
  cat /lib/systemd/system/ceremonyclient.service
  echo ""

  # Display the qclient and grpcurl installation status
  echo -e "\033[1mCurrent qclient and grpcurl installation status:\033[0m"
  ls ~/go/bin
}

# Function: Update the config.yml with Grpc and stats multiaddrs
modify_config() {
  # Stop the service before modifying the config
  stop_service

  # Update the config.yml
  CONFIG_FILE=~/ceremonyclient/node/.config/config.yml
  if [ -f "$CONFIG_FILE" ]; then
    sed -i 's|listenGrpcMultiaddr: ""|listenGrpcMultiaddr: /ip4/127.0.0.1/tcp/8337|' ~/ceremonyclient/node/.config/config.yml && sed -i 's|statsMultiaddr: ""|statsMultiaddr: "/dns/stats.quilibrium.com/tcp/443"|' ~/ceremonyclient/node/.config/config.yml
    echo "File updated: $CONFIG_FILE"
  else
    echo "File not found: $CONFIG_FILE"
  fi

  # Restart the service
  start_service
}

# Function: Install grpcurl and qclient
install_grpc_qclient() {
  cd ~/ceremonyclient/client
  rm ~/go/bin/qclient
  GOEXPERIMENT=arenas go build -o ~/go/bin/qclient main.go
  ls ~/go/bin

  go install github.com/fullstorydev/grpcurl/cmd/grpcurl@latest
}

# Function: Start the node service
start_service() {
  echo "Starting the Quil node service | $(date)"
  service ceremonyclient start
}

# Function: Stop the node service
stop_service() {
  echo "Stopping the Quil node service | $(date)"
  service ceremonyclient stop
}

# Function: Display the logs of the running node service
view_logs() {
  sudo journalctl -u ceremonyclient.service -f --no-hostname -o cat
}

# Function: Use grpcurl to check the node status
check_node_status() {
  grpcurl -plaintext localhost:8337 quilibrium.node.node.pb.NodeService.GetNodeInfo
}

# Function: Sync node to snapshot store file
sync_node() {
  # Install unzip if not already installed
  sudo apt-get update
  sudo apt-get install unzip

  # Download the store snapshot
  cd ~
  wget https://snapshots.cherryservers.com/quilibrium/store.zip

  # Unzip the store snapshot
  unzip store.zip
  rm store.zip

  # Stop the service before replacing the store
  stop_service

  # Replace the store
  mv ~/ceremonyclient/node/.config/store ~/ceremonyclient/node/.config/store.bak
  mv ~/store ~/ceremonyclient/node/.config/

  # Restart the service
  start_service
}

# Function: Backup keys and config files
backup_keys() {
  # Copy the keys and config files to the backup folder
  mkdir -p ~/quil_keys_bak
  cp ~/ceremonyclient/node/.config/keys.yml ~/quil_keys_bak
  cp ~/ceremonyclient/node/.config/config.yml ~/quil_keys_bak

  # Create a tarball of the backup folder
  tar -czvf ~/quil_keys_bak.tar.gz ~/quil_keys_bak
  rm -rf ~/quil_keys_bak

  # Reminder to download the backup file
  echo "Backup file quil_keys_bak.tar.gz has been created."
  echo "Please download the backup file to a secure location, e.g. using scp or sftp."
  echo ""

  # Automatic scp command
  username=$(whoami)
  ip_address=$(curl -s ifconfig.me)
  echo "To download the backup file, run the following command on your local machine:"
  echo "scp $username@$ip_address:~/quil_keys_bak.tar.gz <LOCAL_PATH>"
  echo "Replace <LOCAL_PATH> with the desired path on your local machine."
}

# Function: Upgrade the node
upgrade_node() {
  # Stop the service before upgrading the node
  stop_service

  # Switch the repo and pull the latest changes
  cd ~/ceremonyclient
  git remote set-url origin https://source.quilibrium.com/quilibrium/ceremonyclient.git
  git pull

  # Merge the latest changes
  cd ~/ceremonyclient 
  git reset --hard origin/release
  git fetch --all
  git clean -df
  git merge origin/release

  # Rebuild the qclient
  cd ~/ceremonyclient/client
  rm ~/go/bin/qclient
  GOEXPERIMENT=arenas go build -o ~/go/bin/qclient main.go
  cd ~/ceremonyclient/node

  # Restart the service
  start_service
}

# Function: Main menu
show_menu() {
  # Welcome message
  echo -e "\033[1mQuil Manager v1.0\033[0m"
  echo ""

  # Installation options
  echo -e "\033[1m-------------- Installation ---------------\033[0m"
  echo "1. Node Setup (for first-time use)"
  echo "2. Verify Setup"
  echo "3. Update config.yml"
  echo "4. (Optional) Install grpcurl and qclient"

  # Service management options
  echo -e "\033[1m------------ Service Management -----------\033[0m"
  echo "5. Start Q node service"
  echo "6. Stop Q node service"
  echo "7. View logs"
  echo "8. Check node status (grpcurl required)"

  # Node management options
  echo -e "\033[1m------------ Node Management --------------\033[0m"
  echo "9. Sync node (replace store)"
  echo "10. Backup keys and config files"
  echo "11. Upgrade node"
  
  # Exit option
  echo -e "\033[1m----------- Script Management -------------\033[0m"
  echo "12. Exit"
  echo -e "\033[1m-------------------------------------------\033[0m"

  # Execute the selected option based on user input
  read -p "Please enter an option [1-12]: " option
  case $option in
    1)
      init
      ;;
    2)
      verify
      ;;
    3)
      modify_config
      ;;
    4)
      install_grpc_qclient
      ;;
    5)
      start_service
      ;;
    6)
      stop_service
      ;;
    7)
      view_logs
      ;;
    8)
      check_node_status
      ;;
    9)
      sync_node
      ;;
    10)
      backup_keys
      ;;
    11)
      upgrade_node
      ;;
    12)
      exit 0
      ;;
    *)
      echo "Invalid option. Please try again."
      show_menu
      ;;
  esac
}

# Main
show_menu