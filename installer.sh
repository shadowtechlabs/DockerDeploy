#!/bin/bash
#installer for shok files - sb 2/25
#v.1 test

check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        echo "Error: This script must be run as root"
        exit 1
    fi
}

user_group() {
    while true; do
        read -p "What user should own the application directory? (stl_admin): " USER
        if [ -n "$USER" ]; then
            break
        else
            USER=stl_admin
            break
        fi
    done
    while true; do
        read -p "What user group should own the application directory? (stl_admin): " UGROUP
        if [ -n "$UGROUP" ]; then
            break
        else
            UGROUP=stl_admin
            break
        fi
    done

}

installer() {
    # Declare SHOK home
    local shokenv="SHOK=/opt/shok"
    local conf=/etc/environment
    # Lines to be appended
    local lines=(
        $shokenv
    )
    # Append the lines if they aren't already in the file
    for line in "${lines[@]}"; do
        if ! grep -qF "$line" "$conf"; then
            echo "$line" | sudo tee -a "$conf" > /dev/null
            echo "Added environment variable: $line"
        else
            echo "Environment variable already present: $line"
        fi
    done
    source /etc/environment

    # Make directory and extract files
    user_group
    install -d -o $USER -g $UGROUP $SHOK
    tar -xf shok.tar.gz -C $SHOK

    #Create helper script link
    if [ ! -f /usr/local/bin/helper ]; then
    ln -s $SHOK/helper.sh /usr/local/bin/helper
    fi

}

if [ $# -eq 0 ]; then
    installer
else
    case "$1" in
        --install)
            installer
            ;;
#        --uninstall)
#            uninstall
#            ;;
        *)
            echo "Usage: $0 [-install|]"
            exit 1
            ;;
    esac
fi