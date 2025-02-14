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
    local shokinst=/opt/shok
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
    
    . /etc/environment

    # Make directory and extract files
    user_group
    install -d -o $USER -g $UGROUP $shokinst
    tar -xf shok.tar -C $shokinst

    #Create helper script link
    if [ ! -L /usr/local/bin/helper ]; then
    ln -s $shokinst/helper.sh /usr/local/bin/helper
    fi

    echo "SHOK base scripts install completed."
    if [ -z "$SHOK" ]; then
        echo "The SHOK global variable hasn't registered yet. Please logout and login again."
        echo "The working directory is now "$shokinst
    else
        echo "The working directory for these scripts is "$SHOK"."
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