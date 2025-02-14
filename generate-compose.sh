#!/bin/bash
#generate docker config files for shok deployments - sb 2/25
#v.2 permissions


validate_ip() {
    local ip=$1
    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        return 0
    else
        return 1
    fi
}


# zigbee2mqtt file generation
zigbee2mqtt() {
    # Prompt user for values

    while true; do
            read -p "Enter Zigbee Radio IP address (ZBRADIOIP): " ZBRADIOIP
        read -p "Enter MQTT IP address (MQTTIP): " MQTTIP
        read -p "Enter Zigbee2MQTT Server IP address (ZB2MQTTIP): " ZB2MQTTIP
    
        if validate_ip "$ZBRADIOIP" && validate_ip "$MQTTIP" && validate_ip "$ZB2MQTTIP"; then
            echo "IPs validated"
            break
        else
            echo "Invalid IP format. Please try again."
            exit 1
        fi
    done

    # Define file paths
    CONFIG_YAML="zigbee2mqtt-data/configuration.yaml"
    ZB2MQTT_COMPOSE="zigbee2mqtt-compose.yml"

    # Prune old configs
    rm $CONFIG_YAML 2>/dev/null
    rm $ZB2MQTT_COMPOSE 2>/dev/null

    # Create and populate configuration.yaml
    mkdir -p zigbee2mqtt-data
    cat <<EOF > "$CONFIG_YAML"
version: 4
mqtt:
  base_topic: zigbee2mqtt
  server: mqtt://mqtt
  user: stl_admin
  password: st2012
serial:
  port: tcp://$ZBRADIOIP:6638
  adapter: ember
frontend:
  enabled: true
homeassistant:
  enabled: false
EOF
    # Create and populate zigbee2mqtt-compose.yml
    cat <<EOF > "$ZB2MQTT_COMPOSE"
services:
  mqtt:
    container_name: mqtt_server
    image: eclipse-mosquitto:2.0
    volumes:
      - "./mosquitto-data/config:/mosquitto/config"
      - "./mosquitto-data/data:/mosquitto/data"
      - "./mosquitto-data/log:/mosquitto/log"
    networks:
        shadownet:
            ipv4_address: $MQTTIP
  zigbee2mqtt:
    container_name: zigbee2mqtt
    restart: unless-stopped
    image: koenkk/zigbee2mqtt
    volumes:
      - ./zigbee2mqtt-data:/app/data
      - /run/udev:/run/udev:ro
    environment:
#      - TZ=American/Detroit
      - ZIGBEE2MQTT_CONFIG_MQTT_USER=stl_admin
      - ZIGBEE2MQTT_CONFIG_MQTT_PASSWORD=st2012
      - ZIGBEE2MQTT_CONFIG_MQTT_SERVER=$MQTTIP
      - ZIGBEE2MQTT_CONFIG_FRONTEND_PORT=8080
    networks:
        shadownet:
            ipv4_address: $ZB2MQTTIP
    depends_on:
      - mqtt
networks:
    shadownet:
        name: shadownet
        external: true
EOF

    echo "zigbee2mqtt file generation successful"

}

# avp file generation
avp() {

# Gather IP info
    while true; do
        read -p "Enter AVP Server IP address (AVPIP): " AVPIP
        read -p "Enter AVP Build Number (BUILD): " BUILD
        if validate_ip "$AVPIP"; then
            echo "IP validated"
            break
        else
            echo "Invalid IP format. Please try again."
            exit 1
        fi
    done

    # Define File Paths
    AVP_COMPOSE="avp-compose.yml"
    
    # Prune old config
    rm $AVP_COMPOSE 2>/dev/null

    # Create and populate avp-compose.yml
    cat <<EOF > "$AVP_COMPOSE"
services:
  shadownet_avp:
    container_name: shadownet_avp
    image: shadowtechlabs/dod:$BUILD
    volumes:
      - "./shadownet-config:/hunter/Software/Config"
      - "./shadownet-logs:/hunter/Software/logs"
      - "/etc/timezone:/etc/timezone:ro"
      - "/etc/localtime:/etc/localtime:ro"
    restart: unless-stopped
    networks:
      shadownet:
        ipv4_address: $AVPIP
networks:
    shadownet:
        name: shadownet
        external: true
EOF

    echo "avp file generation successful"

}

if [ $# -eq 0 ]; then
    zigbee2mqtt
    avp
else
    case "$1" in
        --avp-compose.yml)
            avp
            ;;
        --zigbee2mqtt-compose.yml)
            zigbee2mqtt
            ;;
#        --avp-stop)
#            stop_avp
#            ;;
        *)
            echo "Usage: $0 [--avp-compose.yml|--zigbee2mqtt-compose.yml]"
            exit 1
            ;;
    esac
fi
