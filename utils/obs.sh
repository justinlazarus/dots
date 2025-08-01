#!/bin/bash

SERVICE_PLIST="/Library/LaunchDaemons/observiq-otel-collector.plist"
SERVICE_NAME="observiq-otel-collector"

is_running() {
    sudo launchctl list | grep "$SERVICE_NAME" > /dev/null
}

if is_running; then
    echo "observiq-otel-collector is running. Attempting to stop..."
    sudo launchctl bootout system "$SERVICE_PLIST"
    if is_running; then
        echo "Failed to stop observiq-otel-collector."
    else
        echo "observiq-otel-collector stopped successfully."
    fi
else
    echo "observiq-otel-collector is not running."
fi