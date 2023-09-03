#!/bin/bash

# Function to convert IP addresses to numerical representations for comparison
ip2num() {
  local a b c d
  IFS=. read -r a b c d <<< "$1"
  echo "$((a * 256 ** 3 + b * 256 ** 2 + c * 256 + d))"
}

# Function to check if an IP falls within a subnet range
ip_in_subnet() {
  local ip=$1
  local cidr=$2
  local network=$(echo $cidr | cut -d/ -f1)
  local mask=$(echo $cidr | cut -d/ -f2)
  local network_dec=$(echo $network | awk -F. '{printf("%d\n", ($1 * 256 + $2) * 256 + $3)}')
  local ip_dec=$(echo $ip | awk -F. '{printf("%d\n", ($1 * 256 + $2) * 256 + $3)}')
  local mask_dec=$((0xffffffff << (32 - $mask)))
  
  [[ $((ip_dec & mask_dec)) -eq $((network_dec & mask_dec)) ]]
}

# Function to check if an IP address is within a specified range and log changes to syslog
check_ip_range_and_log() {
  local INTERFACE="$1"
  local ACTUAL_IP="$2"
  local EXPECTED_IP_RANGE="$3"
  echo "$ACTUAL_IP $EXPECTED_IP_RANGE"
  
  if ! ip_in_subnet "$ACTUAL_IP" "$EXPECTED_IP_RANGE"; then
    log_and_reboot "$INTERFACE" "WAN IP address is within the expected subnet range ($EXPECTED_IP_RANGE)."
  else
    log_no_action_taken "$INTERFACE" "WAN IP address is not within the expected subnet range ($EXPECTED_IP_RANGE). Skipping."
  fi
}

# Function to log and reboot
log_and_reboot() {
  local INTERFACE="$1"
  local MESSAGE="$2"

  logger -t "WAN-IP-Checker" "$MESSAGE"
  echo "$MESSAGE"
  ifconfig "$INTERFACE" down
  sleep 5
  ifconfig "$INTERFACE" up
  logger -t "WAN-IP-Checker" "$INTERFACE interface rebooted."
  echo "$INTERFACE interface rebooted."
}

# Function to log no action taken
log_no_action_taken() {
  local INTERFACE="$1"
  local MESSAGE="$2"

  logger -t "WAN-IP-Checker" "$MESSAGE"
  echo "$MESSAGE"
}


INTERFACE="pppoe0"
ACTUAL_IP=$(ifconfig "$INTERFACE" | grep 'inet ' | awk '{print $2}')
EXPECTED_IP_RANGE="100.64.0.0/10"  # CIDR for the range 100.64.0.0 to 100.127.255.255 (CGNAT)

check_ip_range_and_log "$INTERFACE" "$ACTUAL_IP" "$EXPECTED_IP_RANGE"
