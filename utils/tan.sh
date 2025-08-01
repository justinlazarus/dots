#!/bin/zsh

SERVICE_PLIST="/Library/LaunchDaemons/com.tanium.taniumclient.plist"
SERVICE_NAME="com.tanium.taniumclient"

is_running() {
    sudo launchctl list | grep "$SERVICE_NAME" > /dev/null
}

if is_running; then
    echo "Tanium client is running. Attempting to stop..."
    sudo launchctl bootout system "$SERVICE_PLIST"
    if is_running; then
        echo "Failed to stop Tanium client."
    else
        echo "Tanium client stopped successfully."
    fi
else
    echo "Tanium client is not running."
fi