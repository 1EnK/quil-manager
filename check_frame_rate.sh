#!/bin/bash

# Define the log file
log_file="$HOME/frame_snapshot.txt"

# Function to extract and log the current values
log_current_values() {
  grpcurl -plaintext localhost:8337 quilibrium.node.node.pb.NodeService.GetNodeInfo | jq -r '"\(.peerId)|\(.maxFrame)"' | while read -r line; do
    current_time=$(date +%s)
    echo "$line|$current_time" >> "$log_file"
  done
}

# Function to calculate the rate of frame increase
calculate_frame_rate() {
  # Read the first and the last entry from the log file
  first_entry=$(head -n 1 "$log_file")
  last_entry=$(tail -n 1 "$log_file")

  # Extract values from the first and last entries
  first_frame=$(echo "$first_entry" | awk -F'|' '{print $2}')
  first_time=$(echo "$first_entry" | awk -F'|' '{print $3}')
  last_frame=$(echo "$last_entry" | awk -F'|' '{print $2}')
  last_time=$(echo "$last_entry" | awk -F'|' '{print $3}')

  # Calculate the frame increase frame_rate
  frame_diff=$((last_frame - first_frame))
  time_diff=$((last_time - first_time))

  if [[ $time_diff -ne 0 ]]; then
    frame_rate=$(echo "scale=2; $frame_diff / $time_diff" | bc)
    frame_rate_min=$(echo "scale=2; $frame_rate * 60" | bc)
    frame_rate_hour=$(echo "scale=2; $frame_rate * 3600" | bc)
    frame_rate_day=$(echo "scale=2; $frame_rate * 86400" | bc)

    # Get peerId from the first entry
    peerId=$(echo "$first_entry" | awk -F'|' '{print $1}')

    # Print the frame synchroneization rate
    echo "-------------------------------------------------------"
    echo "PeerId: $peerId"
    echo "-------------------------------------------------------"
    echo "Max frame: $last_frame | $(date)"
    echo "-------------------------------------------------------"
    echo "Current rate: $frame_rate / second"
    echo "Projected rate: $frame_rate_min / minute"
    echo "Projected rate: $frame_rate_hour / hour"
    echo "Projected rate: $frame_rate_day / day"
    echo "-------------------------------------------------------"
  else
    echo "Frame increase rate: 0 frames per second"
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
  unset first_entry last_entry first_frame first_time last_frame last_time frame_diff time_diff frame_rate frame_rate_min frame_rate_hour frame_rate_day peerId current_time line
}

# Initialize the script
check_prerequisites

# Log & Calculation
log_current_values
calculate_frame_rate

# Clean up
clean_variables