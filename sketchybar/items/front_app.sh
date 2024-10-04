#!/bin/sh

sketchybar --add item front_app left \
           --set front_app      icon.font="sketchybar-app-font:Regular:16.0" \
                                script=$PLUGIN_DIR/front_app.sh \
                                background.color=$ACCENT_COLOR \
                                background.corner_radius=5 \
                                background.padding_right=20 \
                                background.padding_left=20 \
                                icon.padding_left=10 \
                                icon.padding_right=10 \
                                label.padding_right=10 \
           --subscribe front_app front_app_switched
