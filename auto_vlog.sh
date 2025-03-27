#!/bin/bash

## Set Colors
BLACK_BG_GREEN_TEXT="\033[40;32m"
RESET="\033[0m"

# Set Path - Find the directory containing Fv-Vlog-Source.log
SOURCE_DEVICE=$(find /storage -type f -name "Fv-Vlog-Source.log" | sed 's|/Fv-Vlog-Source.log||')
if [ -z "$SOURCE_DEVICE" ]; then
    echo -e "${BLACK_BG_GREEN_TEXT}[ERROR] Source device with Fv-Vlog-Source.log not found!${RESET}"
    exit 1
fi
printf "${BLACK_BG_GREEN_TEXT}[Info] Source device: %s${RESET}\n" "$SOURCE_DEVICE"

# Set destination directory
DEST_DEVICE="/storage/emulated/0/DCIM/DJI_001"
echo -e "${BLACK_BG_GREEN_TEXT}[Info] Destination directory: $DEST_DEVICE${RESET}"

RUN_ENV_DIR="$SOURCE_DEVICE/DJI_001"

# Check if source directory exists
cd "$RUN_ENV_DIR" || { echo -e "${BLACK_BG_GREEN_TEXT}[ERROR] Directory $RUN_ENV_DIR does not exist!${RESET}"; exit 1; }

echo -e "${BLACK_BG_GREEN_TEXT}[Info] Start processing MP4 files${RESET}"

# Delete LRF files
echo -e "${BLACK_BG_GREEN_TEXT}[Info] Deleting LRF files...${RESET}"
find . -name "*.LRF" -exec rm -rf {} \;
echo -e "${BLACK_BG_GREEN_TEXT}..........[ DONE ]${RESET}"

# Function to get file date and time
get_file_datetime() {
    stat -c "%y" "$1" | awk '{print $1"_"substr($2, 1, 5)}' | sed 's/[-:]//g'
}

# Process all MP4 files
for file in *.MP4; do
    if [ -f "$file" ]; then
        datetime=$(get_file_datetime "$file")
        new_name="VLOG_${datetime}.MP4"
        echo -e "${BLACK_BG_GREEN_TEXT}[Info] Renaming $file to $new_name${RESET}"
        cp "$file" "$DEST_DEVICE/$new_name"
        echo -e "${BLACK_BG_GREEN_TEXT}..........[ DONE ]${RESET}"
    fi
done

echo -e "${BLACK_BG_GREEN_TEXT}[Info] All files processed and copied to $DEST_DEVICE${RESET}"