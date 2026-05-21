#!/bin/bash

if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    echo "Usage:"
    echo "  $0 -install"
    echo "  $0 -setBG <name> <video_file>"
    echo
    echo "Description:"
    echo "  Installs the Multi_Background SDDM theme and allows"
    echo "  setting custom background videos for users."
    echo
    echo "Flags:"
    echo "  -install"
    echo "      Installs the SDDM theme to:"
    echo "      /usr/share/sddm/themes/Multi_Background"
    echo
    echo "      Also sets the theme as the current SDDM theme"
    echo "      by updating the SDDM configuration."
    echo
    echo "  -setBG <name> <video_file>"
    echo "      Sets a background video for a user."
    echo
    echo "Arguments:"
    echo "  <name>         Username for whom to set background"
    echo "  <video_file>   Path to the mp4 video file"
    echo
    echo "Examples:"
    echo "  $0 -install"
    echo "  $0 -setBG ocean ~/Videos/ocean.mp4"
    exit 0
fi

if [ "$1" = "-setBG" ]; then
    sudo cp "$3" /usr/share/sddm/themes/Multi_Background/$2.mp4
fi

if [ "$1" = "-install" ]; then
    sudo mkdir /usr/share/sddm/themes/Multi_Background
    sudo cp -r ./* /usr/share/sddm/themes/Multi_Background/

    THEME="Multi_Background"
    sudo mkdir -p /etc/sddm.conf.d
    echo "[Theme]
Current=$THEME" | sudo tee /etc/sddm.conf
fi