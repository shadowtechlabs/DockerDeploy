These base scripts will assist you in:
  1. Installing the helper script.
  2. Installing Docker.
  3. Creating the required shadownet Docker network.
  4. Generating the required avp-compose.yml, zigbee2mqtt-compose.yml, & zigbee2mqtt configuration.conf files, as well as the proper file structure.
  5. Checking the status of your SHOK deployment.


INSTALLING:

Usage: download and run the installer using the following command:

git clone https://github.com/shadowtechlabs/DockerDeploy
cd DockerDeploy && chmod +x installer.sh
sudo ./installer.sh

The working directory after the script has been ran will be /opt/shok.

Once completed, you may run ./helper.sh to install Docker, create the Docker network, generate AVP and Zigbee2MQTT compose files, and more. 

USAGE:

Working directory: /opt/shok

From the working directory, you may run helper to show the following menu:
1) Check Status
2) Start AVP
3) Stop AVP
4) Start Zigbee2MQTT
5) Stop Zigbee2MQTT
6) Create Network
7) Disable IPV6
8) Exit

Report errors or comments to Shane.
