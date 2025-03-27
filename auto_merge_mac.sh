#!/bin/bash

###Debugging
MERGE_PATH=""/Volumes/SSD2T/FvDriveMerged
RUN_ENV_DIR="/Volumes/SSD2T/DCIM/100MEDIA"

#!/bin/bash

## Set Colors
BLACK_BG_GREEN_TEXT="\033[40;32m"
BLACK_BG_YELLOW_TEXT="\033[40;33m"
RESET="\033[0m"

## Set Path
# SOURCE_DEVICE=$(find /Volumes -type f -name "Fv-Merge-Original.log" | sed 's|/Fv-Merge-Original.log||')
# if [ -z "$SOURCE_DEVICE" ]; then
#     echo -e "${BLACK_BG_GREEN_TEXT}[ERROR] Source device with Fv-Merge-Original.log not found!${RESET}"
#     exit 1
# fi
# printf "${BLACK_BG_GREEN_TEXT}[Info] Source device: %s${RESET}\n" "$SOURCE_DEVICE"

# echo -e -n "${BLACK_BG_YELLOW_TEXT}[ASKING] Set Destination to LOCAL DEVICE(FvOutput/Fv-MediaFolder/Merged-Ma8p)?（y/n）${RESET}"
# read -r answer
# if [ "$answer" != "${answer#[Yy]}" ]; then
#     echo -e "${BLACK_BG_GREEN_TEXT}[Info-ENTERED] Yes, Setting to LOCAL${RESET}"
#     DEST_DEVICE=~/FvOutput
#     echo -e "${BLACK_BG_GREEN_TEXT}..........[ DONE ]${RESET}"
# else
#     echo -e "${BLACK_BG_GREEN_TEXT}[Info] No, Finding Fv-Merge-Destination.log${RESET}"
#     DEST_DEVICE=$(find /Volumes -type f -name "Fv-Merge-Destination.log" | sed 's|/Fv-Merge-Destination.log||')
#     echo -e "${BLACK_BG_GREEN_TEXT}..........[ DONE ]${RESET}"

#     if [ -z "$DEST_DEVICE" ]; then
#         echo -e "${BLACK_BG_GREEN_TEXT}[ERROR] Destination device with Fv-Merge-Destination.log not found!${RESET}"
#         exit 1
#     fi
#     echo -e "${BLACK_BG_GREEN_TEXT}[Info] Destination device: $DEST_DEVICE${RESET}"
# fi

# MERGE_PATH="$DEST_DEVICE/Fv-MediaFolder/Merged-Ma8p"
# RUN_ENV_DIR="$SOURCE_DEVICE/DCIM/100MEDIA"

cd "$RUN_ENV_DIR" || { echo -e "${BLACK_BG_GREEN_TEXT}[ERROR] Directory $RUN_ENV_DIR does not exist!${RESET}"; exit 1; }

echo -e "${BLACK_BG_GREEN_TEXT}[Info] Start merging the files${RESET}"

# Delete LRF files
echo -e -n "${BLACK_BG_GREEN_TEXT}[Info] Deleting LRF files${RESET}"
find . -name "*.LRF" -exec rm -rf {} \;
echo -e "${BLACK_BG_GREEN_TEXT}..........[ DONE ]${RESET}"

# Set size threshold for 3.4 GB (in bytes)
SIZE_THRESHOLD=$((3 * 1024 * 1024 * 1024 + 500 * 1024 * 1024))

# Sort files by name
sorted_files=($(ls -1 *.MP4 | sort))
total_files=${#sorted_files[@]}  # Total number of files

# Initialize variables for merging
group=()
index=1
last_large_file=""
processed_files=0

# Function to display progress
show_progress() {
    local current=$1
    local total=$2
    local percent=$(( current * 100 / total ))
    local progress_bar_length=$(( percent / 5 ))
    local progress_bar=$(printf "%0.s#" $(seq 1 $progress_bar_length))
    printf "[%s%s] (%d/%d %d%%)\n" "$progress_bar" "$(printf "%0.s " $(seq 1 $((20 - progress_bar_length))))" "$current" "$total" "$percent"
}

# Function to get file date and time (macOS uses `-f` for stat)
get_file_datetime() {
    stat -f "%Sm" -t "%Y%m%d_%H%M" "$1" | cut -d' ' -f1
}

# Function to merge the group of files
merge_group() {
    if [ ${#group[@]} -gt 0 ]; then
        first_file="${group[0]}"
        last_file="${group[@]: -1}"  # Correctly get the last file in the group
        datetime=$(get_file_datetime "$first_file")
        group_name="${datetime}_$(basename "$first_file" .MP4)-$(basename "$last_file" .MP4).mp4"
        echo -e "${BLACK_BG_GREEN_TEXT}[Info] Merging group $index into $group_name${RESET}"
        for file in "${group[@]}"; do
            echo "file '$file'" >> list.txt
        done
        ffmpeg -f concat -safe 0 -i list.txt -c copy "$MERGE_PATH/$group_name" -hide_banner -loglevel error
        rm list.txt
        echo -e "${BLACK_BG_GREEN_TEXT}..........[ DONE ]${RESET}"
        group=()
        last_large_file=""  # 清空 last_large_file，避免后续的独立文件被错误合并
        ((index++))
    fi
}

# Process files
for file in "${sorted_files[@]}"; do
    file_size=$(stat -f%z "$file")
    ((processed_files++))

    # 显示当前进度
    show_progress "$processed_files" "$total_files"

    # 如果文件大于阈值，将其视为大文件并加入当前组
    if (( file_size >= SIZE_THRESHOLD )); then
        echo "处理大文件 $file, 加入当前组"
        group+=("$file")
        last_large_file="$file"

    # 如果文件小于阈值，且前面有大文件，将其加入组并结束该组
    elif (( file_size < SIZE_THRESHOLD )) && [ -n "$last_large_file" ]; then
        echo "处理小文件 $file, 加入当前组并结束该组"
        group+=("$file")
        merge_group

    # 否则，将其视为独立小文件
    else
        # 先合并当前组
        if [ ${#group[@]} -gt 0 ]; then
            merge_group
        fi
        # 处理独立小文件
        datetime=$(get_file_datetime "$file")
        new_name="${datetime}_$(basename "$file" .MP4).mp4"
        echo -e "${BLACK_BG_GREEN_TEXT}[Info] Copying standalone file $file to $MERGE_PATH/$new_name${RESET}"
        cp "$file" "$MERGE_PATH/$new_name"
        echo -e "${BLACK_BG_GREEN_TEXT}..........[ DONE ]${RESET}"
    fi
done

# 如果最后有未合并的组，将其合并
if [ ${#group[@]} -gt 0 ]; then
    merge_group
fi

echo -e "${BLACK_BG_GREEN_TEXT}[Info] Job Completed.${RESET}"