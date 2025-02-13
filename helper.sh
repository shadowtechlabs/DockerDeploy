#!/bin/bash
# avp helper script - SB Jan '25
#v.1

auto_update() {
    if confirm "Do you want to run system updates now?"; then
        apt update && apt upgrade -y
    else
        echo "Skipping updates."
    fi

}

check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        echo "Error: This script must be run as root"
        exit 1
    fi
}

check_docker() {
    if ! command -v docker &> /dev/null; then
        echo "Error: Docker is not installed"
        if confirm "Do you want to install it now?"; then
            install_docker
        else
            echo "Docker is required. Exiting..."
            exit 1
        fi
    fi
    
    if ! docker info &> /dev/null; then
        echo "Error: Docker daemon is not running"
        exit 1
    fi
}

confirm() {
  # Usage: confirm "Your prompt message"
  while true; do
    read -r -p "$1 [y/n]: " answer
    case "$answer" in
      [Yy]* ) return 0 ;;  # Yes
      [Nn]* ) return 1 ;;  # No
      * ) echo "Please answer yes or no." ;;
    esac
  done
}

install_docker() {
    # Ensure the script is running on Ubuntu
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        if [ "$ID" != "ubuntu" ]; then
            echo "This installation script is intended for Ubuntu. Exiting."
            return 1
        fi
    else
        echo "Unable to detect the operating system. Exiting."
        return 1
    fi

    # Remove any unofficial or legacy Docker releases
    echo "Removing any unofficial Docker installations if they exist..."
    sudo apt-get remove -y docker docker-engine docker.io containerd runc

    # Remove existing Docker Compose binary (possibly unofficial)
    if [ -f /usr/local/bin/docker-compose ]; then
        echo "Removing existing Docker Compose installation..."
        sudo rm /usr/local/bin/docker-compose
    fi

    echo "Updating apt package index and installing prerequisites..."
    sudo apt-get update
    sudo apt-get install -y \
        apt-transport-https \
        ca-certificates \
        curl \
        gnupg \
        lsb-release

    echo "Adding Docker's official GPG key..."
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

    echo "Setting up the Docker stable repository..."
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    echo "Updating apt package index..."
    sudo apt-get update

    echo "Installing Docker Engine..."
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io

    echo "Installing Docker Compose..."
    # Fetch the latest release tag for Docker Compose from GitHub
    DOCKER_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d\" -f4)
    sudo curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose

    echo "Adding current user ($USER) to the docker group..."
    sudo usermod -aG docker $USER

    echo "Installation complete. Please log out and log back in for group changes to take effect."
}

check_compose_file() {
    local file=$1
    if [ ! -f "$file" ]; then
        echo "Error: Docker Compose file '$file' not found"
        if confirm "Do you want to create it now?"; then
            giant turd test ./generate-compose.sh --$file
        else
            echo "Aborting..."
            exit 1
        fi
    fi
}

disable_ipv6() {

    # Path to sysctl config
    local conf="/etc/sysctl.conf"
    # Lines to be appended
    local lines=(
        "net.ipv6.conf.all.disable_ipv6 = 1"
        "net.ipv6.conf.default.disable_ipv6 = 1"
        "net.ipv6.conf.lo.disable_ipv6 = 1"
    )

    # Append the lines if they aren't already in the file
    for line in "${lines[@]}"; do
        if ! grep -qF "$line" "$conf"; then
            echo "$line" | sudo tee -a "$conf" > /dev/null
            echo "Appended: $line"
        else
            echo "Line already present: $line"
        fi
    done

    # Reload sysctl to apply settings
    sysctl -p
}

validate_ip() {
    local ip=$1
    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        return 0
    else
        return 1
    fi
}

validate_subnet() {
    local subnet=$1
    if [[ $subnet =~ ^[0-9]{1,2}$ ]] && [ $subnet -ge 0 ] && [ $subnet -le 32 ]; then
        return 0
    else
        return 1
    fi
}


# Function to detect the active adapter based on the default route.
detect_active_adapter() {
  # The default route usually specifies the active network adapter.
  default_iface=$(ip route | awk '/default/ {print $5; exit}')
  echo "$default_iface"
}

# Function to list all physical ethernet adapters, ignoring loopback and docker/bridge interfaces.
list_physical_adapters() {
  for iface in $(ls /sys/class/net); do
    # Skip loopback interface
    if [ "$iface" == "lo" ]; then
      continue
    fi
    # Skip docker and bridge interfaces (common naming conventions)
    if [[ $iface == docker* ]] || [[ $iface == br-* ]]; then
      continue
    fi
    # Check if the interface is physical by ensuring a 'device' directory exists
    if [ -d /sys/class/net/"$iface"/device ]; then
      echo "$iface"
    fi
  done
}

# Function to display a selection menu with the active adapter suggested.
select_network_adapter() {
  active_adapter=$(detect_active_adapter)
  echo "Detected active network adapter: $active_adapter"
  
  # Build an array of available adapters.
  adapters=()
  while IFS= read -r adapter; do
    adapters+=("$adapter")
  done < <(list_physical_adapters)
  
  # If the active adapter isn’t already first in the list, move it to the top.
  if [[ ${adapters[0]} != "$active_adapter" ]]; then
    # Remove active_adapter from its current position if it exists.
    for i in "${!adapters[@]}"; do
      if [ "${adapters[$i]}" = "$active_adapter" ]; then
        unset 'adapters[i]'
      fi
    done
    # Prepend the active adapter.
    adapters=("$active_adapter" "${adapters[@]}")
  fi
  
  echo "Select a network adapter for the parent interface:"
  PS3="Enter choice number: "
  select adapter in "${adapters[@]}"; do
    if [[ -n "$adapter" ]]; then
      echo "You selected: $adapter"
      break
    else
      echo "Invalid selection. Try again."
    fi
  done
}


check_interface() {
    if ! ip link show "$1" >/dev/null 2>&1; then
        return 1
    fi
    return 0
}


create_network() {
    while true; do
        read -p "Enter the network name: (shadownet) " network_name
        if [ -n "$network_name" ]; then
            break
        else
            network_name=shadownet
            break
        fi
    done

    while true; do
        select_network_adapter
        if check_interface "$adapter"; then
            break
        else
            echo "Interface $adapter does not exist. Please try again."
        fi
    done

    while true; do
        read -p "Enter subnet address (e.g., 192.168.1.0): " subnet_addr
        read -p "Enter subnet mask (0-32): " subnet_mask
        
        if validate_ip "$subnet_addr" && validate_subnet "$subnet_mask"; then
            subnet="$subnet_addr/$subnet_mask"
            break
        else
            echo "Invalid subnet format. Please try again."
        fi
    done

    while true; do
        read -p "Enter gateway address: " gateway
        if validate_ip "$gateway"; then
            break
        else
            echo "Invalid gateway format. Please try again."
        fi
    done

    if docker network inspect "$network_name" >/dev/null 2>&1; then
        echo "Network $network_name already exists. Please choose a different name."
        return 1
    fi

    echo "Creating Docker network with the following configuration:"
    echo "Network Name: $network_name"
    echo "Parent Interface: $adapter"
    echo "Subnet: $subnet"
    echo "Gateway: $gateway"

    docker network create \
        --driver ipvlan \
        --subnet "$subnet" \
        --gateway "$gateway" \
        -o parent="$adapter" \
        -o ipvlan_mode=l2 \
        "$network_name"

    if [ $? -eq 0 ]; then
        echo "Network $network_name created successfully!"
    else
        echo "Failed to create network. Please check your configuration and try again."
        return 1
    fi
}

start_avp() {
    check_compose_file "avp-compose.yml"
    echo "Starting AVP stack..."
    docker compose -f avp-compose.yml up -d
}

stop_avp() {
    check_compose_file "avp-compose.yml"
    echo "Stopping AVP stack..."
    docker compose -f avp-compose.yml down
}

start_zigbee() {
    check_compose_file "zigbee2mqtt-compose.yml"
    echo "Starting Zigbee2MQTT stack..."
    docker compose -f zigbee2mqtt-compose.yml up -d
}

stop_zigbee() {
    check_compose_file "zigbee2mqtt-compose.yml"
    echo "Stopping Zigbee2MQTT stack..."
    docker compose -f zigbee2mqtt-compose.yml down
}

check_status() {
if docker ps --format '{{.Names}}' | grep -q shadownet_avp; then
  echo -e "Container shadownet_avp is \033[32m running\033[0m."
else
  echo -e "Container shadownet_avp is \033[31mnot running\033[0m."
fi
if docker ps --format '{{.Names}}' | grep -q zigbee2mqtt; then
  echo -e "Container zigbee2mqtt is \033[32m running\033[0m."
else
  echo -e "Container zigbee2mqtt is \033[31mnot running\033[0m."
fi
if docker ps --format '{{.Names}}' | grep -q mqtt_server; then
  echo -e "Container mqtt_server is \033[32m running\033[0m."
else
  echo -e "Container mqtt_server is \033[31mnot running\033[0m."
fi
if docker network ls --format '{{.Name}}' | grep -q shadownet; then
  echo -e "Network shadownet is \033[32m running\033[0m."
else
  echo -e "Network shadownet is \033[31mnot running\033[0m."
fi
}

show_menu() {
    PS3="Please select an option: "
    options=("Check Status" "Start AVP" "Stop AVP" "Start Zigbee2MQTT" "Stop Zigbee2MQTT" "Create Network" "Disable IPV6" "Exit")
    select opt in "${options[@]}"
    do
        case $opt in
            "Check Status")
                check_status
                break
                ;;
            "Start AVP")
                start_avp
                break
                ;;
            "Stop AVP")
                stop_avp
                break
                ;;
            "Start Zigbee2MQTT")
                start_zigbee
                break
                ;;
            "Stop Zigbee2MQTT")
                stop_zigbee
                break
                ;;
            "Create Network")
                create_network
                break
                ;;
            "Disable IPV6")
                disable_ipv6
                break
                ;;
            "Exit")
                exit 0
                ;;
            *) 
                echo "Invalid option $REPLY"
                ;;
        esac
    done
}

main() {
    check_root
    check_docker

    if [ $# -eq 0 ]; then
        show_menu
    else
        case "$1" in
            --check-status)
                check_status
                ;;
            --avp-start)
                start_avp
                ;;
            --avp-stop)
                stop_avp
                ;;
            --zigbee2mqtt-start)
                start_zigbee
                ;;
            --zigbee2mqtt-stop)
                stop_zigbee
                ;;
            --create-network)
                create_network
                ;;
            --disable-ipv6)
                disable_ipv6
                ;;
            *)
                echo "Usage: $0 [--check-status|--avp-start|--avp-stop|--zigbee2mqtt-start|--zigbee2mqtt-stop|--create-network|--disable-ipv6]"
                exit 1
                ;;
        esac
    fi
}

main "$@"