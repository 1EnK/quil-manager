#!/bin/bash

# Define the log file
log_file="$HOME/reward_snapshot.txt"

# Function to extract and log the current values
log_current_values() {
  # Change directory and extract the unclaimed balance
  cd ~/ceremonyclient/node
  peerId=$(./node-1.4.19-linux-amd64 --node-info | grep 'Peer ID:' | awk '{print $3}')
  balance=$(./node-1.4.19-linux-amd64 --node-info | grep 'Unclaimed balance' | awk '{print $3}')
  
  current_time=$(date +%s)
  echo "$peerId|$balance|$current_time" >> "$log_file"
}

# Function to calculate the rate of reward increase
calculate_reward_rate() {
  # Read the first and the last entry from the log file
  first_entry=$(head -n 1 "$log_file")
  last_entry=$(tail -n 1 "$log_file")

  # If last and first entries are the same, then snapshot one more time
  if [ "$first_entry" == "$last_entry" ]; then
    echo "Initializing the log file..."
    log_current_values
    last_entry=$(tail -n 1 "$log_file")
  fi

  # Extract values from the first and last entries
  first_reward=$(echo "$first_entry" | awk -F'|' '{print $2}')
  first_time=$(echo "$first_entry" | awk -F'|' '{print $3}')
  last_reward=$(echo "$last_entry" | awk -F'|' '{print $2}')
  last_time=$(echo "$last_entry" | awk -F'|' '{print $3}')

  # Calculate the reward increase reward_rate
  reward_diff=$(echo "$last_reward - $first_reward" | bc)
  time_diff=$(echo "$last_time - $first_time" | bc)

  if (( $(echo "$time_diff != 0" | bc -l) )); then
    reward_rate=$(echo "scale=6; $reward_diff / $time_diff" | bc)
    reward_rate_min=$(echo "scale=6; $reward_rate * 60" | bc)
    reward_rate_hour=$(echo "scale=6; $reward_rate * 3600" | bc)
    reward_rate_day=$(echo "scale=6; $reward_rate * 86400" | bc)

    # Get peerId from the first entry
    peerId=$(echo "$first_entry" | awk -F'|' '{print $1}')

    # Print the reward synchroneization rate
    echo "-------------------------------------------------------"
    echo "PeerId: $peerId"
    echo "-------------------------------------------------------"
    echo "Current unclaimed reward: $last_reward | $(date)"
    echo "-------------------------------------------------------"
    echo "Current rate: $reward_rate / second"
    echo "Projected rate: $reward_rate_min / minute"
    echo "Projected rate: $reward_rate_hour / hour"
    echo "Projected rate: $reward_rate_day / day"
    echo "-------------------------------------------------------"
  else
    echo "Invalid data. Please check or remove the log file: $log_file"
  fi
}

# Check the prerequisites
check_prerequisites() {
  if ! command -v jq &> /dev/null || ! command -v bc &> /dev/null; then
    echo "Prerequisites missing. Installing..."
    install_prerequisites
  fi
}

# Install prerequisites
install_prerequisites() {
  sudo apt-get update
  sudo apt-get install -y jq
  sudo apt-get install -y bc
}

# Clean up the variables
clean_variables() {
  unset log_file
  unset first_entry last_entry first_reward first_time last_reward last_time reward_diff time_diff reward_rate reward_rate_min reward_rate_hour reward_rate_day peerId current_time line
}

# Initialize the script
check_prerequisites

# Log & Calculation
log_current_values
calculate_reward_rate

# Clean up
clean_variables