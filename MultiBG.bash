#!/bin/bash

if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    echo "Usage:"
    echo "  $0 -setBG <name> <video_file>"
    echo
    echo "Description:"
    echo "  Sets an SDDM background video theme."
    echo
    echo "Arguments:"
    echo "  <name>         username for whom to set background"
    echo "  <video_file>   Path to the mp4 video file"
    echo
    echo "Example:"
    echo "  $0 -setBG ocean ~/Videos/ocean.mp4"
    exit 0
fi

if [ "$1" = "-setBG" ]; then
    sudo cp "$3" /usr/share/sddm/themes/Multi_Background/$2.mp4
fi