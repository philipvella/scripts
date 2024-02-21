#!/bin/bash

# Script to process a video file with ffmpeg

# Check if two arguments are given
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <input_file> <output_file>"
    exit 1
fi

# Assign the first argument to input_file and second to output_file
input_file="$1"
output_file="$2"

# Run ffmpeg with the provided input and output file names
ffmpeg -i "$input_file" -vf mpdecimate,setpts=N/FRAME_RATE/TB "$output_file"
